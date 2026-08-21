/*
 * hard-tools: lib/uvc_daemon.c
 * USB Video Class (UVC 1.00) Gadget Userspace Daemon & Shared-Memory Video Engine
 *
 * Implements complete Linux f_uvc event loop (UVCIOC_SETUP, UVCIOC_SEND_RESPONSE, STREAMON, STREAMOFF)
 * Supports zero-copy / atomic live video injection via /dev/shm/uvc_frame.raw with SMPTE test pattern fallback.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <signal.h>
#include <stdint.h>
#include <stdbool.h>

#include <linux/videodev2.h>
#include <linux/usb/ch9.h>
#include <linux/usb/g_uvc.h>

/* UVC Control Request Codes */
#define UVC_RC_UNDEFINED                0x00
#define UVC_SET_CUR                     0x01
#define UVC_GET_CUR                     0x81
#define UVC_GET_MIN                     0x82
#define UVC_GET_MAX                     0x83
#define UVC_GET_RES                     0x84
#define UVC_GET_LEN                     0x85
#define UVC_GET_INFO                    0x86
#define UVC_GET_DEF                     0x87

/* VideoStreaming Interface Control Selectors */
#define UVC_VS_CONTROL_UNDEFINED        0x00
#define UVC_VS_PROBE_CONTROL            0x01
#define UVC_VS_COMMIT_CONTROL           0x02
#define UVC_VS_STILL_PROBE_CONTROL      0x03
#define UVC_VS_STILL_COMMIT_CONTROL     0x04

/* Camera Terminal Control Selectors (Unit 1) */
#define UVC_CT_CONTROL_UNDEFINED            0x00
#define UVC_CT_SCANNING_MODE_CONTROL        0x01
#define UVC_CT_AE_MODE_CONTROL              0x02
#define UVC_CT_AE_PRIORITY_CONTROL          0x03
#define UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL 0x04

/* Processing Unit Control Selectors (Unit 2) */
#define UVC_PU_CONTROL_UNDEFINED            0x00
#define UVC_PU_BACKLIGHT_COMPENSATION_CONTROL 0x01
#define UVC_PU_BRIGHTNESS_CONTROL           0x02
#define UVC_PU_CONTRAST_CONTROL             0x03
#define UVC_PU_GAIN_CONTROL                 0x04
#define UVC_PU_POWER_LINE_FREQUENCY_CONTROL 0x05
#define UVC_PU_HUE_CONTROL                  0x06
#define UVC_PU_SATURATION_CONTROL           0x07
#define UVC_PU_SHARPNESS_CONTROL            0x08
#define UVC_PU_GAMMA_CONTROL                0x09

#define NUM_BUFFERS 4
#define DEFAULT_WIDTH 640
#define DEFAULT_HEIGHT 360
#define FRAME_SIZE_YUYV (DEFAULT_WIDTH * DEFAULT_HEIGHT * 2) /* 460800 bytes */
#define UVC_FRAME_PATH "/dev/shm/uvc_frame.raw"
#define UVC_FRAME_FALLBACK "/tmp/uvc_frame.raw"

/* Exact 26-byte UVC 1.00 Streaming Control structure */
struct uvc_streaming_control {
    uint16_t bmHint;
    uint8_t  bFormatIndex;
    uint8_t  bFrameIndex;
    uint32_t dwFrameInterval;
    uint16_t wKeyFrameRate;
    uint16_t wPFrameRate;
    uint16_t wCompQuality;
    uint16_t wCompWindowSize;
    uint16_t wDelay;
    uint32_t dwMaxVideoFrameSize;
    uint32_t dwMaxPayloadTransferSize;
} __attribute__((__packed__));

struct buffer {
    void *start;
    size_t length;
};

static volatile bool g_running = true;
static bool g_streaming = false;
static int g_dev_fd = -1;
static struct buffer g_buffers[NUM_BUFFERS];
static unsigned int g_num_buffers = 0;

static struct uvc_streaming_control g_probe;
static struct uvc_streaming_control g_commit;
static uint8_t g_current_cs = 0;
static uint8_t g_current_entity = 0;

/* Control States */
static int16_t g_brightness = 128;
static int16_t g_contrast = 128;
static int16_t g_saturation = 128;
static int16_t g_hue = 0;
static uint8_t g_power_line_freq = 1; /* 50Hz */
static uint32_t g_exposure_time = 156; /* 1/64s */
static uint8_t g_ae_mode = 2; /* Auto Mode */

static int g_current_width = DEFAULT_WIDTH;
static int g_current_height = DEFAULT_HEIGHT;

static void sig_handler(int sig) {
    (void)sig;
    g_running = false;
}

static void fill_probe_defaults(struct uvc_streaming_control *ctrl) {
    memset(ctrl, 0, sizeof(*ctrl));
    ctrl->bmHint = 1;
    ctrl->bFormatIndex = 1;
    ctrl->bFrameIndex = 1;
    ctrl->dwFrameInterval = 333333; /* 30 fps (10,000,000 / 30) */
    ctrl->wKeyFrameRate = 0;
    ctrl->wPFrameRate = 0;
    ctrl->wCompQuality = 0;
    ctrl->wCompWindowSize = 0;
    ctrl->wDelay = 0;
    ctrl->dwMaxVideoFrameSize = FRAME_SIZE_YUYV;
    ctrl->dwMaxPayloadTransferSize = 3072;
}

static int uvc_subscribe_events(int fd) {
    struct v4l2_event_subscription sub;
    unsigned int events[] = {
        UVC_EVENT_CONNECT,
        UVC_EVENT_DISCONNECT,
        UVC_EVENT_STREAMON,
        UVC_EVENT_STREAMOFF,
        UVC_EVENT_SETUP,
        UVC_EVENT_DATA,
    };
    for (size_t i = 0; i < sizeof(events) / sizeof(events[0]); i++) {
        memset(&sub, 0, sizeof(sub));
        sub.type = events[i];
        if (ioctl(fd, VIDIOC_SUBSCRIBE_EVENT, &sub) < 0) {
            fprintf(stderr, "[!] Warning: failed to subscribe to event %u: %s\n", events[i], strerror(errno));
        }
    }
    return 0;
}

static void generate_test_pattern(uint8_t *buf, int width, int height, int frame_num) {
    static const uint8_t colors[8][4] = {
        { 235, 128, 235, 128 }, /* White */
        { 210,  16, 210, 146 }, /* Yellow */
        { 170, 166, 170,  16 }, /* Cyan */
        { 145,  54, 145,  34 }, /* Green */
        { 106, 202, 106, 222 }, /* Magenta */
        {  81,  90,  81, 240 }, /* Red */
        {  41, 240,  41, 110 }, /* Blue */
        {  16, 128,  16, 128 }, /* Black */
    };

    int bar_width = width / 8;
    int line_stride = width * 2;

    for (int y = 0; y < height; y++) {
        uint8_t *row = buf + y * line_stride;
        for (int x = 0; x < width; x += 2) {
            int bar_idx = (x / bar_width) % 8;
            row[x * 2 + 0] = colors[bar_idx][0];
            row[x * 2 + 1] = colors[bar_idx][1];
            row[x * 2 + 2] = colors[bar_idx][2];
            row[x * 2 + 3] = colors[bar_idx][3];
        }
    }

    int bounce_h = height / 5;
    int start_y = height - bounce_h;
    int box_size = 40;
    int box_x = (frame_num * 8) % (width - box_size);

    for (int y = start_y; y < height; y++) {
        uint8_t *row = buf + y * line_stride;
        for (int x = box_x; x < box_x + box_size; x += 2) {
            if (x * 2 + 3 < line_stride) {
                row[x * 2 + 0] = 255;
                row[x * 2 + 1] = 128;
                row[x * 2 + 2] = 255;
                row[x * 2 + 3] = 128;
            }
        }
    }
}

static bool get_video_frame(uint8_t *buf, int frame_num) {
    const char *path = (access(UVC_FRAME_PATH, R_OK) == 0) ? UVC_FRAME_PATH : UVC_FRAME_FALLBACK;
    int fd = open(path, O_RDONLY);
    if (fd >= 0) {
        struct stat st;
        if (fstat(fd, &st) == 0 && st.st_size == FRAME_SIZE_YUYV) {
            ssize_t r = read(fd, buf, FRAME_SIZE_YUYV);
            close(fd);
            if (r == FRAME_SIZE_YUYV) {
                return true;
            }
        } else {
            close(fd);
        }
    }

    generate_test_pattern(buf, g_current_width, g_current_height, frame_num);
    return false;
}

static int start_video_stream(int fd) {
    if (g_streaming) return 0;

    printf("[+] Initializing V4L2 streaming buffers (%dx%d YUYV)...\n", g_current_width, g_current_height);

    struct v4l2_format fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
    fmt.fmt.pix.width = g_current_width;
    fmt.fmt.pix.height = g_current_height;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
    fmt.fmt.pix.field = V4L2_FIELD_NONE;
    if (ioctl(fd, VIDIOC_S_FMT, &fmt) < 0) {
        fprintf(stderr, "[!] S_FMT failed: %s\n", strerror(errno));
        return -1;
    }

    struct v4l2_requestbuffers req;
    memset(&req, 0, sizeof(req));
    req.count = NUM_BUFFERS;
    req.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
    req.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_REQBUFS, &req) < 0) {
        fprintf(stderr, "[!] REQBUFS failed: %s\n", strerror(errno));
        return -1;
    }

    g_num_buffers = req.count;
    for (unsigned int i = 0; i < req.count; i++) {
        struct v4l2_buffer buf;
        memset(&buf, 0, sizeof(buf));
        buf.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
        buf.memory = V4L2_MEMORY_MMAP;
        buf.index = i;
        if (ioctl(fd, VIDIOC_QUERYBUF, &buf) < 0) {
            fprintf(stderr, "[!] QUERYBUF %u failed: %s\n", i, strerror(errno));
            return -1;
        }

        g_buffers[i].length = buf.length;
        g_buffers[i].start = mmap(NULL, buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, buf.m.offset);
        if (g_buffers[i].start == MAP_FAILED) {
            fprintf(stderr, "[!] mmap buffer %u failed: %s\n", i, strerror(errno));
            return -1;
        }

        get_video_frame((uint8_t *)g_buffers[i].start, i);

        buf.bytesused = FRAME_SIZE_YUYV;
        if (ioctl(fd, VIDIOC_QBUF, &buf) < 0) {
            fprintf(stderr, "[!] Initial QBUF %u failed: %s\n", i, strerror(errno));
            return -1;
        }
    }

    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
    if (ioctl(fd, VIDIOC_STREAMON, &type) < 0) {
        fprintf(stderr, "[!] STREAMON failed: %s\n", strerror(errno));
        return -1;
    }

    g_streaming = true;
    printf("[+] UVC Video Stream ACTIVE. Frame generation running.\n");
    return 0;
}

static int stop_video_stream(int fd) {
    if (!g_streaming) return 0;

    g_streaming = false;
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
    ioctl(fd, VIDIOC_STREAMOFF, &type);

    for (unsigned int i = 0; i < g_num_buffers; i++) {
        if (g_buffers[i].start && g_buffers[i].start != MAP_FAILED) {
            munmap(g_buffers[i].start, g_buffers[i].length);
            g_buffers[i].start = NULL;
        }
    }
    g_num_buffers = 0;

    struct v4l2_requestbuffers req;
    memset(&req, 0, sizeof(req));
    req.count = 0;
    req.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
    req.memory = V4L2_MEMORY_MMAP;
    ioctl(fd, VIDIOC_REQBUFS, &req);

    printf("[+] UVC Video Stream STOPPED.\n");
    return 0;
}

/* Handle VideoStreaming Interface Requests (Probe / Commit) */
static void handle_streaming_control(int fd, struct usb_ctrlrequest *ctrl, struct uvc_request_data *resp) {
    uint8_t cs = (ctrl->wValue >> 8) & 0xff;
    struct uvc_streaming_control *target = (cs == UVC_VS_COMMIT_CONTROL) ? &g_commit : &g_probe;

    g_current_cs = cs;
    g_current_entity = 0;

    switch (ctrl->bRequest) {
        case UVC_SET_CUR:
            resp->length = ctrl->wLength;
            break;
        case UVC_GET_CUR:
        case UVC_GET_MIN:
        case UVC_GET_MAX:
        case UVC_GET_DEF:
        case UVC_GET_RES:
            resp->length = sizeof(struct uvc_streaming_control);
            if (resp->length > ctrl->wLength) resp->length = ctrl->wLength;
            memcpy(resp->data, target, resp->length);
            break;
        case UVC_GET_LEN:
            resp->length = 2;
            resp->data[0] = sizeof(struct uvc_streaming_control) & 0xff;
            resp->data[1] = (sizeof(struct uvc_streaming_control) >> 8) & 0xff;
            break;
        case UVC_GET_INFO:
            resp->length = 1;
            resp->data[0] = 0x03;
            break;
        default:
            resp->length = -EL2HLT;
            break;
    }
}

/* Handle Processing Unit (Unit 2) Requests */
static void handle_processing_unit(int fd, struct usb_ctrlrequest *ctrl, struct uvc_request_data *resp) {
    uint8_t cs = (ctrl->wValue >> 8) & 0xff;
    g_current_cs = cs;
    g_current_entity = 2;

    switch (ctrl->bRequest) {
        case UVC_GET_INFO:
            resp->length = 1;
            resp->data[0] = 0x03;
            break;
        case UVC_GET_LEN:
            resp->length = 2;
            resp->data[0] = (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) ? 1 : 2;
            resp->data[1] = 0;
            break;
        case UVC_GET_MIN:
            resp->length = (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) ? 1 : 2;
            memset(resp->data, 0, resp->length);
            break;
        case UVC_GET_MAX:
            if (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) {
                resp->length = 1;
                resp->data[0] = 2;
            } else {
                resp->length = 2;
                resp->data[0] = 0xFF;
                resp->data[1] = 0x00;
            }
            break;
        case UVC_GET_RES:
            resp->length = (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) ? 1 : 2;
            memset(resp->data, 0, resp->length);
            resp->data[0] = 1;
            break;
        case UVC_GET_DEF:
            if (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) {
                resp->length = 1;
                resp->data[0] = 1;
            } else {
                resp->length = 2;
                resp->data[0] = 128;
                resp->data[1] = 0;
            }
            break;
        case UVC_GET_CUR:
            if (cs == UVC_PU_POWER_LINE_FREQUENCY_CONTROL) {
                resp->length = 1;
                resp->data[0] = g_power_line_freq;
            } else if (cs == UVC_PU_BRIGHTNESS_CONTROL) {
                resp->length = 2;
                resp->data[0] = g_brightness & 0xff;
                resp->data[1] = (g_brightness >> 8) & 0xff;
            } else if (cs == UVC_PU_CONTRAST_CONTROL) {
                resp->length = 2;
                resp->data[0] = g_contrast & 0xff;
                resp->data[1] = (g_contrast >> 8) & 0xff;
            } else if (cs == UVC_PU_SATURATION_CONTROL) {
                resp->length = 2;
                resp->data[0] = g_saturation & 0xff;
                resp->data[1] = (g_saturation >> 8) & 0xff;
            } else {
                resp->length = (ctrl->wLength > sizeof(resp->data)) ? sizeof(resp->data) : ctrl->wLength;
                memset(resp->data, 0, resp->length);
                if (resp->length >= 1) resp->data[0] = 128;
            }
            break;
        case UVC_SET_CUR:
            resp->length = ctrl->wLength;
            break;
        default:
            resp->length = -EL2HLT;
            break;
    }
}

/* Handle Camera Terminal (Unit 1) Requests */
static void handle_camera_terminal(int fd, struct usb_ctrlrequest *ctrl, struct uvc_request_data *resp) {
    uint8_t cs = (ctrl->wValue >> 8) & 0xff;
    g_current_cs = cs;
    g_current_entity = 1;

    switch (ctrl->bRequest) {
        case UVC_GET_INFO:
            resp->length = 1;
            resp->data[0] = 0x03;
            break;
        case UVC_GET_LEN:
            resp->length = 2;
            resp->data[0] = (cs == UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL) ? 4 : 1;
            resp->data[1] = 0;
            break;
        case UVC_GET_MIN:
            if (cs == UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL) {
                resp->length = 4;
                uint32_t min_exp = 100;
                memcpy(resp->data, &min_exp, 4);
            } else {
                resp->length = 1;
                resp->data[0] = 1;
            }
            break;
        case UVC_GET_MAX:
            if (cs == UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL) {
                resp->length = 4;
                uint32_t max_exp = 10000;
                memcpy(resp->data, &max_exp, 4);
            } else {
                resp->length = 1;
                resp->data[0] = 4;
            }
            break;
        case UVC_GET_RES:
            if (cs == UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL) {
                resp->length = 4;
                uint32_t res = 1;
                memcpy(resp->data, &res, 4);
            } else {
                resp->length = 1;
                resp->data[0] = 1;
            }
            break;
        case UVC_GET_DEF:
        case UVC_GET_CUR:
            if (cs == UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL) {
                resp->length = 4;
                memcpy(resp->data, &g_exposure_time, 4);
            } else if (cs == UVC_CT_AE_MODE_CONTROL) {
                resp->length = 1;
                resp->data[0] = g_ae_mode;
            } else {
                resp->length = (ctrl->wLength > sizeof(resp->data)) ? sizeof(resp->data) : ctrl->wLength;
                memset(resp->data, 0, resp->length);
            }
            break;
        case UVC_SET_CUR:
            resp->length = ctrl->wLength;
            break;
        default:
            resp->length = -EL2HLT;
            break;
    }
}

static void handle_uvc_setup(int fd, struct usb_ctrlrequest *ctrl) {
    struct uvc_request_data resp;
    memset(&resp, 0, sizeof(resp));

    uint8_t req_type = ctrl->bRequestType & USB_TYPE_MASK;
    uint8_t req_dir  = ctrl->bRequestType & USB_DIR_IN;
    uint8_t entity_id = (ctrl->wIndex >> 8) & 0xff;
    uint8_t iface_num = ctrl->wIndex & 0xff;
    uint8_t cs        = (ctrl->wValue >> 8) & 0xff;

    if (req_type == USB_TYPE_CLASS) {
        if (iface_num == 1 || cs == UVC_VS_PROBE_CONTROL || cs == UVC_VS_COMMIT_CONTROL) {
            handle_streaming_control(fd, ctrl, &resp);
        } else if (entity_id == 2) {
            handle_processing_unit(fd, ctrl, &resp);
        } else if (entity_id == 1) {
            handle_camera_terminal(fd, ctrl, &resp);
        } else {
            switch (ctrl->bRequest) {
                case UVC_GET_INFO:
                    resp.length = 1;
                    resp.data[0] = 0x03;
                    break;
                case UVC_GET_CUR:
                case UVC_GET_DEF:
                    resp.length = (ctrl->wLength > sizeof(resp.data)) ? sizeof(resp.data) : ctrl->wLength;
                    memset(resp.data, 0, resp.length);
                    if (resp.length >= 1) resp.data[0] = 128;
                    break;
                case UVC_GET_MIN:
                    resp.length = (ctrl->wLength > sizeof(resp.data)) ? sizeof(resp.data) : ctrl->wLength;
                    memset(resp.data, 0, resp.length);
                    break;
                case UVC_GET_MAX:
                    resp.length = (ctrl->wLength > sizeof(resp.data)) ? sizeof(resp.data) : ctrl->wLength;
                    memset(resp.data, 0xff, resp.length);
                    break;
                case UVC_GET_RES:
                    resp.length = (ctrl->wLength > sizeof(resp.data)) ? sizeof(resp.data) : ctrl->wLength;
                    memset(resp.data, 0, resp.length);
                    if (resp.length >= 1) resp.data[0] = 1;
                    break;
                case UVC_GET_LEN:
                    resp.length = 2;
                    resp.data[0] = 2;
                    resp.data[1] = 0;
                    break;
                case UVC_SET_CUR:
                    resp.length = ctrl->wLength;
                    break;
                default:
                    resp.length = -EL2HLT;
                    break;
            }
        }
    } else {
        resp.length = -EL2HLT;
    }

    if (req_dir == USB_DIR_IN || ctrl->bRequest == UVC_SET_CUR || resp.length < 0) {
        ioctl(fd, UVCIOC_SEND_RESPONSE, &resp);
    }
}

static void handle_uvc_data(int fd, struct uvc_request_data *data) {
    if (g_current_cs == UVC_VS_PROBE_CONTROL && data->length >= sizeof(struct uvc_streaming_control)) {
        memcpy(&g_probe, data->data, sizeof(struct uvc_streaming_control));
    } else if (g_current_cs == UVC_VS_COMMIT_CONTROL && data->length >= sizeof(struct uvc_streaming_control)) {
        memcpy(&g_commit, data->data, sizeof(struct uvc_streaming_control));
    }
}

int main(int argc, char *argv[]) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    const char *dev_path = (argc > 1) ? argv[1] : "/dev/video2";

    printf("====================================================\n");
    printf("  hard-tools UVC 1.00 Gadget Streaming Engine\n");
    printf("====================================================\n");
    printf("[*] Target V4L2 Gadget Node: %s\n", dev_path);
    printf("[*] Video Frame Buffer:      %s\n", UVC_FRAME_PATH);
    printf("[*] UVC Probe Struct Size:   %zu bytes (UVC 1.00 Compliant)\n", sizeof(struct uvc_streaming_control));

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    fill_probe_defaults(&g_probe);
    fill_probe_defaults(&g_commit);

    g_dev_fd = open(dev_path, O_RDWR | O_NONBLOCK);
    if (g_dev_fd < 0) {
        fprintf(stderr, "[!] Error: failed to open %s: %s\n", dev_path, strerror(errno));
        return 1;
    }

    uvc_subscribe_events(g_dev_fd);
    printf("[+] Subscribed to UVC kernel events. Listening for host connections...\n");

    int frame_counter = 0;

    while (g_running) {
        fd_set read_fds, write_fds, except_fds;
        FD_ZERO(&read_fds);
        FD_ZERO(&write_fds);
        FD_ZERO(&except_fds);
        FD_SET(g_dev_fd, &read_fds);
        FD_SET(g_dev_fd, &except_fds);

        if (g_streaming) {
            FD_SET(g_dev_fd, &write_fds);
        }

        struct timeval tv = { .tv_sec = 0, .tv_usec = 10000 }; /* 10ms fast tick */
        int ret = select(g_dev_fd + 1, &read_fds, g_streaming ? &write_fds : NULL, &except_fds, &tv);

        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        struct v4l2_event ev;
        memset(&ev, 0, sizeof(ev));
        while (ioctl(g_dev_fd, VIDIOC_DQEVENT, &ev) == 0) {
            switch (ev.type) {
                case UVC_EVENT_CONNECT:
                    printf("[+] Host CONNECT event on UVC interface.\n");
                    break;
                case UVC_EVENT_DISCONNECT:
                    printf("[-] Host DISCONNECT event on UVC interface.\n");
                    stop_video_stream(g_dev_fd);
                    break;
                case UVC_EVENT_STREAMON:
                    printf("[+] Host STREAMON event!\n");
                    start_video_stream(g_dev_fd);
                    break;
                case UVC_EVENT_STREAMOFF:
                    printf("[-] Host STREAMOFF event.\n");
                    stop_video_stream(g_dev_fd);
                    break;
                case UVC_EVENT_SETUP: {
                    struct uvc_event *uvc_ev = (struct uvc_event *)&ev.u.data;
                    handle_uvc_setup(g_dev_fd, &uvc_ev->req);
                    break;
                }
                case UVC_EVENT_DATA: {
                    struct uvc_event *uvc_ev = (struct uvc_event *)&ev.u.data;
                    handle_uvc_data(g_dev_fd, &uvc_ev->data);
                    break;
                }
                default:
                    break;
            }
        }

        if (g_streaming && FD_ISSET(g_dev_fd, &write_fds)) {
            struct v4l2_buffer buf;
            memset(&buf, 0, sizeof(buf));
            buf.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
            buf.memory = V4L2_MEMORY_MMAP;

            if (ioctl(g_dev_fd, VIDIOC_DQBUF, &buf) == 0) {
                get_video_frame((uint8_t *)g_buffers[buf.index].start, frame_counter++);
                buf.bytesused = FRAME_SIZE_YUYV;
                if (g_streaming) {
                    ioctl(g_dev_fd, VIDIOC_QBUF, &buf);
                }
            }
        }
    }

    printf("\n[*] Stopping UVC daemon...\n");
    stop_video_stream(g_dev_fd);
    close(g_dev_fd);
    printf("[+] UVC daemon exited cleanly.\n");
    return 0;
}

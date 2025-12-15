#include <IOKit/IOKitLib.h>
#include <math.h>
#include <pthread.h>
#include <mach/mach_time.h>
#include <sys/sysctl.h>

#include "include/SMCBridge.h"

#define SMC_CACHE_TTL_NS 100000000ULL
#define SMC_MAX_RETRIES 3
#define SMC_BATCH_SIZE 16

typedef struct __attribute__((packed)) {
    uint32_t key;
    uint8_t pad0[24];
    uint32_t size;
    uint8_t pad1[10];
    uint8_t command;
    uint8_t pad2[5];
    union {
        float f32;
        uint32_t u32;
        uint16_t u16;
        uint8_t u8;
        int16_t i16;
        int8_t i8;
    } value;
    uint8_t pad3[28];
} SMCData;

typedef struct {
    uint32_t key;
    uint8_t type;
    uint8_t size;
} SMCKeyInfo;

static struct {
    SMCBridgeData data;
    uint64_t timestamp;
    pthread_mutex_t mutex;
    io_connect_t connection;
    bool initialized;
} g_smc_cache = {
    .mutex = PTHREAD_MUTEX_INITIALIZER,
    .connection = IO_OBJECT_NULL,
    .initialized = false
};

static inline uint64_t mach_time_ns(void) {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    return (mach_absolute_time() * timebase.numer) / timebase.denom;
}

static bool smc_ensure_connection(void) {
    if (g_smc_cache.connection != IO_OBJECT_NULL) return true;
    
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return false;
    
    IOReturn ret = IOServiceOpen(service, mach_task_self(), 1, &g_smc_cache.connection);
    IOObjectRelease(service);
    
    return (ret == kIOReturnSuccess && g_smc_cache.connection != IO_OBJECT_NULL);
}

static bool smc_read_raw(uint32_t key, uint8_t size, void *value) {
    if (!smc_ensure_connection()) return false;
    
    SMCData input = {0}, output = {0};
    size_t output_size = sizeof(output);
    
    input.key = key;
    input.size = size;
    input.command = 5;
    
    for (int retry = 0; retry < SMC_MAX_RETRIES; retry++) {
        IOReturn ret = IOConnectCallStructMethod(g_smc_cache.connection, 2, 
                                               &input, sizeof(input),
                                               &output, &output_size);
        if (ret == kIOReturnSuccess) {
            memcpy(value, &output.value, size);
            return true;
        }
        
        if (ret == kIOReturnNotOpen || ret == kIOReturnExclusiveAccess) {
            IOServiceClose(g_smc_cache.connection);
            g_smc_cache.connection = IO_OBJECT_NULL;
            if (!smc_ensure_connection()) return false;
        }
    }
    return false;
}

static inline bool smc_read_float(uint32_t key, float *value) {
    return smc_read_raw(key, 4, value);
}

static inline bool smc_read_u16(uint32_t key, uint16_t *value) {
    return smc_read_raw(key, 2, value);
}

static inline bool smc_read_i16(uint32_t key, int16_t *value) {
    return smc_read_raw(key, 2, value);
}

static inline bool smc_read_u8(uint32_t key, uint8_t *value) {
    return smc_read_raw(key, 1, value);
}

static inline bool smc_read_fp78(uint32_t key, float *value) {
    int16_t raw;
    if (!smc_read_i16(key, &raw)) return false;
    *value = (float)raw * 0.00390625f;
    return true;
}

static const uint32_t SMC_KEYS[] = {
    0x50535452,
    0x50445452,
    0x42304156,
    0x42304143,
    0x41432D57,
    0x42304354,
    0x54423054,
    0x54423154,
    0x54423254,
    0x54423354,
    0x54433042,
};

static bool smc_read_all_data(SMCBridgeData *data) {
    memset(data, 0, sizeof(*data));
    data->timestamp = mach_time_ns();
    
    smc_read_float(0x50535452, &data->systemPowerW);
    
    smc_read_float(0x50445452, &data->adapterPowerW);
    
    uint16_t mv;
    if (smc_read_u16(0x42304156, &mv)) {
        data->batteryVoltageV = (float)mv * 0.001f;
    } else {
        data->batteryVoltageV = NAN;
    }
    
    int16_t ma;
    if (smc_read_i16(0x42304143, &ma)) {
        data->batteryAmperageA = (float)ma * 0.001f;
    } else {
        data->batteryAmperageA = NAN;
    }
    
    if (!isnan(data->batteryVoltageV) && !isnan(data->batteryAmperageA)) {
        data->batteryPowerW = data->batteryVoltageV * data->batteryAmperageA;
    } else {
        data->batteryPowerW = NAN;
    }
    
    uint8_t port = 0;
    smc_read_u8(0x41432D57, &port);
    if (port > 4) port = 0;
    
    uint32_t adapter_key = 0x44305652 + ((uint32_t)port << 16);
    if (smc_read_u16(adapter_key, &mv)) {
        data->adapterVoltageV = (float)mv * 0.001f;
    } else {
        data->adapterVoltageV = NAN;
    }
    
    if (!isnan(data->adapterPowerW) && !isnan(data->adapterVoltageV) && data->adapterVoltageV > 0.01f) {
        data->adapterAmperageA = data->adapterPowerW / data->adapterVoltageV;
    } else {
        data->adapterAmperageA = NAN;
    }
    
    static const uint32_t temp_keys[] = {0x54423054, 0x54423154, 0x54423254, 0x54423354, 0x54433042};
    data->batteryTemperatureC = NAN;
    for (size_t i = 0; i < sizeof(temp_keys)/sizeof(temp_keys[0]); i++) {
        if (smc_read_fp78(temp_keys[i], &data->batteryTemperatureC)) break;
    }
    
    uint16_t cycles;
    if (smc_read_u16(0x42304354, &cycles)) {
        data->batteryCycleCount = (int32_t)cycles;
    } else {
        data->batteryCycleCount = -1;
    }
    
    return true;
}

bool SMCBridgeReadAll(SMCBridgeData *data) {
    if (!data) return false;
    
    pthread_mutex_lock(&g_smc_cache.mutex);
    
    uint64_t now = mach_time_ns();
    if (g_smc_cache.initialized && (now - g_smc_cache.timestamp) < SMC_CACHE_TTL_NS) {
        *data = g_smc_cache.data;
        pthread_mutex_unlock(&g_smc_cache.mutex);
        return true;
    }
    
    bool success = smc_read_all_data(&g_smc_cache.data);
    if (success) {
        g_smc_cache.timestamp = now;
        g_smc_cache.initialized = true;
        *data = g_smc_cache.data;
    }
    
    pthread_mutex_unlock(&g_smc_cache.mutex);
    return success;
}

void SMCBridgeInvalidateCache(void) {
    pthread_mutex_lock(&g_smc_cache.mutex);
    g_smc_cache.initialized = false;
    g_smc_cache.timestamp = 0;
    if (g_smc_cache.connection != IO_OBJECT_NULL) {
        IOServiceClose(g_smc_cache.connection);
        g_smc_cache.connection = IO_OBJECT_NULL;
    }
    pthread_mutex_unlock(&g_smc_cache.mutex);
}



__attribute__((destructor))
static void smc_cleanup(void) {
    SMCBridgeInvalidateCache();
}

#include <IOKit/IOKitLib.h>
#include <math.h>

#include "SMCBridge.h"

typedef struct {
  uint32_t key;
  char unused0[24];
  uint32_t size;
  char unused1[10];
  char command;
  char unused2[5];
  float value;
  char unused3[28];
} AppleSMCData_Float;

typedef struct {
  uint32_t key;
  char unused0[24];
  uint32_t size;
  char unused1[10];
  char command;
  char unused2[5];
  uint16_t value;
  char unused3[30];
} AppleSMCData_Int16;

static BOOL SMCReadSignedFixedPoint78(uint32_t key, float *outValue) {
  io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault,
                                                 IOServiceMatching("AppleSMC"));
  if (!smc) {
    return NO;
  }

  io_connect_t conn = IO_OBJECT_NULL;
  IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
  if (result != kIOReturnSuccess || conn == IO_OBJECT_NULL) {
    IOObjectRelease(smc);
    return NO;
  }

  AppleSMCData_Int16 inStruct;
  AppleSMCData_Int16 outStruct;
  size_t outStructSize = sizeof(outStruct);
  bzero(&inStruct, sizeof(inStruct));
  bzero(&outStruct, sizeof(outStruct));

  inStruct.command = 5;
  inStruct.size = 2;
  inStruct.key = key;

  result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(inStruct),
                                     &outStruct, &outStructSize);
  IOServiceClose(conn);
  IOObjectRelease(smc);

  if (result != kIOReturnSuccess) {
    return NO;
  }

  int16_t raw = (int16_t)outStruct.value;
  *outValue = ((float)raw) / 256.0f;
  return YES;
}

static BOOL SMCReadFloat(uint32_t key, float *outValue) {
  io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault,
                                                 IOServiceMatching("AppleSMC"));
  if (!smc) {
    return NO;
  }

  io_connect_t conn = IO_OBJECT_NULL;
  IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
  if (result != kIOReturnSuccess || conn == IO_OBJECT_NULL) {
    IOObjectRelease(smc);
    return NO;
  }

  AppleSMCData_Float inStruct;
  AppleSMCData_Float outStruct;
  size_t outStructSize = sizeof(outStruct);
  bzero(&inStruct, sizeof(inStruct));
  bzero(&outStruct, sizeof(outStruct));

  inStruct.command = 5;
  inStruct.size = 4;
  inStruct.key = key;

  result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(inStruct),
                                     &outStruct, &outStructSize);
  IOServiceClose(conn);
  IOObjectRelease(smc);

  if (result != kIOReturnSuccess) {
    return NO;
  }

  *outValue = outStruct.value;
  return YES;
}

static BOOL SMCReadUInt16(uint32_t key, uint16_t *outValue) {
  io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault,
                                                 IOServiceMatching("AppleSMC"));
  if (!smc) {
    return NO;
  }

  io_connect_t conn = IO_OBJECT_NULL;
  IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
  if (result != kIOReturnSuccess || conn == IO_OBJECT_NULL) {
    IOObjectRelease(smc);
    return NO;
  }

  AppleSMCData_Int16 inStruct;
  AppleSMCData_Int16 outStruct;
  size_t outStructSize = sizeof(outStruct);
  bzero(&inStruct, sizeof(inStruct));
  bzero(&outStruct, sizeof(outStruct));

  inStruct.command = 5;
  inStruct.size = 2;
  inStruct.key = key;

  result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(inStruct),
                                     &outStruct, &outStructSize);
  IOServiceClose(conn);
  IOObjectRelease(smc);

  if (result != kIOReturnSuccess) {
    return NO;
  }

  *outValue = outStruct.value;
  return YES;
}

static BOOL SMCReadInt16(uint32_t key, int16_t *outValue) {
  uint16_t raw = 0;
  if (!SMCReadUInt16(key, &raw)) {
    return NO;
  }
  *outValue = (int16_t)raw;
  return YES;
}

static BOOL SMCReadInt8(uint32_t key, int8_t *outValue) {
  io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault,
                                                 IOServiceMatching("AppleSMC"));
  if (!smc) {
    return NO;
  }

  io_connect_t conn = IO_OBJECT_NULL;
  IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
  if (result != kIOReturnSuccess || conn == IO_OBJECT_NULL) {
    IOObjectRelease(smc);
    return NO;
  }

  AppleSMCData_Int16 inStruct;
  AppleSMCData_Int16 outStruct;
  size_t outStructSize = sizeof(outStruct);
  bzero(&inStruct, sizeof(inStruct));
  bzero(&outStruct, sizeof(outStruct));

  inStruct.command = 5;
  inStruct.size = 1;
  inStruct.key = key;

  result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(inStruct),
                                     &outStruct, &outStructSize);
  IOServiceClose(conn);
  IOObjectRelease(smc);

  if (result != kIOReturnSuccess) {
    return NO;
  }

  *outValue = (int8_t)(outStruct.value & 0x00FF);
  return YES;
}

float SMCBridgeGetRawSystemPowerW(void) {
  float v = NAN;
  uint32_t key = ('P' << 24) + ('S' << 16) + ('T' << 8) + 'R';
  if (SMCReadFloat(key, &v)) {
    return v;
  }
  return NAN;
}

float SMCBridgeGetAdapterPowerW(void) {
  float v = NAN;
  uint32_t key = ('P' << 24) + ('D' << 16) + ('T' << 8) + 'R';
  if (SMCReadFloat(key, &v)) {
    return v;
  }
  return NAN;
}

float SMCBridgeGetBatteryVoltageV(void) {
  uint16_t mv = 0;
  uint32_t key = ('B' << 24) + ('0' << 16) + ('A' << 8) + 'V';
  if (!SMCReadUInt16(key, &mv)) {
    return NAN;
  }
  return ((float)mv) / 1000.0f;
}

float SMCBridgeGetBatteryAmperageA(void) {
  int16_t ma = 0;
  uint32_t key = ('B' << 24) + ('0' << 16) + ('A' << 8) + 'C';
  if (!SMCReadInt16(key, &ma)) {
    return NAN;
  }
  return ((float)ma) / 1000.0f;
}

float SMCBridgeGetBatteryPowerW(void) {
  float v = SMCBridgeGetBatteryVoltageV();
  float a = SMCBridgeGetBatteryAmperageA();
  if (isnan(v) || isnan(a)) {
    return NAN;
  }
  return v * a;
}

float SMCBridgeGetAdapterVoltageV(void) {
  int8_t activePort = 0;
  uint32_t winnerPortKey = ('A' << 24) + ('C' << 16) + ('-' << 8) + 'W';
  (void)SMCReadInt8(winnerPortKey, &activePort);

  if (activePort < 0 || activePort > 4) {
    activePort = 0;
  }

  uint16_t mv = 0;
  uint32_t key =
      ('D' << 24) + ((uint32_t)('0' + activePort) << 16) + ('V' << 8) + 'R';
  if (!SMCReadUInt16(key, &mv)) {
    return NAN;
  }
  return ((float)mv) / 1000.0f;
}

float SMCBridgeGetAdapterAmperageA(void) {
  float p = SMCBridgeGetAdapterPowerW();
  float v = SMCBridgeGetAdapterVoltageV();
  if (isnan(p) || isnan(v) || v <= 0.01f) {
    return NAN;
  }
  return p / v;
}

float SMCBridgeGetBatteryTemperatureC(void) {
  float t = NAN;

  uint32_t keysToTry[] = {('T' << 24) + ('B' << 16) + ('0' << 8) + 'T',
                          ('T' << 24) + ('B' << 16) + ('1' << 8) + 'T',
                          ('T' << 24) + ('B' << 16) + ('2' << 8) + 'T',
                          ('T' << 24) + ('B' << 16) + ('3' << 8) + 'T',
                          ('T' << 24) + ('C' << 16) + ('0' << 8) + 'B'};
  int n = (int)(sizeof(keysToTry) / sizeof(keysToTry[0]));

  for (int i = 0; i < n; i++) {
    if (SMCReadSignedFixedPoint78(keysToTry[i], &t)) {
      return t;
    }
  }

  return NAN;
}

int32_t SMCBridgeGetBatteryCycleCount(void) {
  uint16_t cycles = 0;
  uint32_t key = ('B' << 24) + ('0' << 16) + ('C' << 8) + 'T';
  if (!SMCReadUInt16(key, &cycles)) {
    return -1;
  }
  return (int32_t)cycles;
}

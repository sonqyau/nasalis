#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

float SMCBridgeGetRawSystemPowerW(void);
float SMCBridgeGetAdapterPowerW(void);
float SMCBridgeGetAdapterVoltageV(void);
float SMCBridgeGetAdapterAmperageA(void);
float SMCBridgeGetBatteryVoltageV(void);
float SMCBridgeGetBatteryAmperageA(void);
float SMCBridgeGetBatteryPowerW(void);
float SMCBridgeGetBatteryTemperatureC(void);
int32_t SMCBridgeGetBatteryCycleCount(void);

#ifdef __cplusplus
}
#endif

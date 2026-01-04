#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  float systemPowerW;
  float adapterPowerW;
  float adapterVoltageV;
  float adapterAmperageA;
  float batteryVoltageV;
  float batteryAmperageA;
  float batteryPowerW;
  float batteryTemperatureC;
  int32_t batteryCycleCount;
  uint64_t timestamp;
} SMCBridgeData;

bool SMCBridgeReadAll(SMCBridgeData *data);
void SMCBridgeInvalidateCache(void);

#ifdef __cplusplus
}
#endif

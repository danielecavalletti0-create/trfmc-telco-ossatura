import { RFOperationalDeckV34R1NativeBridgeVisible } from './RFOperationalDeckV34R1NativeBridgeVisible'
import { RFDynamicScenarioDeckV36 } from '../../rf_scenarios/RFDynamicScenarioDeckV36'

export function RFOperationalDeckV36VisualScenarioRuntime() {
  return (
    <>
      <RFDynamicScenarioDeckV36 />
      <RFOperationalDeckV34R1NativeBridgeVisible />
    </>
  )
}

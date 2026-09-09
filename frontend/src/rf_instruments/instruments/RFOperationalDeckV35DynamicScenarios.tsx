import { RFOperationalDeckV34R1NativeBridgeVisible } from './RFOperationalDeckV34R1NativeBridgeVisible'
import { RFDynamicScenarioDeckV35 } from '../../rf_scenarios/RFDynamicScenarioDeckV35'

export function RFOperationalDeckV35DynamicScenarios() {
  return (
    <>
      <RFDynamicScenarioDeckV35 />
      <RFOperationalDeckV34R1NativeBridgeVisible />
    </>
  )
}

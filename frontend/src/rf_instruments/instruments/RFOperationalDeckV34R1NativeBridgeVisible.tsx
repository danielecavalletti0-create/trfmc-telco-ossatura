import { RFOperationalDeckV32R1LiveContracts } from './RFOperationalDeckV32R1LiveContracts'
import { RFNativeLiveReadinessStripV34R1 } from '../telemetry/RFNativeLiveReadinessStripV34R1'

export function RFOperationalDeckV34R1NativeBridgeVisible() {
  return (
    <>
      <RFNativeLiveReadinessStripV34R1 />
      <RFOperationalDeckV32R1LiveContracts />
    </>
  )
}

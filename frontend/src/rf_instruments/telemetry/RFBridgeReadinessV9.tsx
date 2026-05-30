import { RFBridgeReadinessV9 as RFBridgeReadinessV9Base } from './RFBridgeReadinessV9Base'
import { RFNativeLiveReadinessStripV34R1 } from './RFNativeLiveReadinessStripV34R1'

export function RFBridgeReadinessV9() {
  return (
    <>
      <RFNativeLiveReadinessStripV34R1 />
      <RFBridgeReadinessV9Base />
    </>
  )
}

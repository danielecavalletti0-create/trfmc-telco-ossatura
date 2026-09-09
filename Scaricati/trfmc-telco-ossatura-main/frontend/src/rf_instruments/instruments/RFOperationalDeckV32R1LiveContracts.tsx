import { RFOperationalDeckV16ChunkObservatory } from './RFOperationalDeckV16ChunkObservatory'
import { RFLiveContractStatusV32R1 } from '../telemetry/RFLiveContractStatusV32R1'

export function RFOperationalDeckV32R1LiveContracts() {
  return (
    <>
      <RFLiveContractStatusV32R1 />
      <RFOperationalDeckV16ChunkObservatory />
    </>
  )
}

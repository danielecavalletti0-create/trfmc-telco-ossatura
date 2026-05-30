import { ScenarioKnowledgeBindingV40 } from '../../knowledge_binding/ScenarioKnowledgeBindingV40'
import { RFOperationalDeckV39NavigationFusion } from './RFOperationalDeckV39NavigationFusion'

export function RFOperationalDeckV40ScenarioKnowledgeFusion() {
  return (
    <>
      <ScenarioKnowledgeBindingV40 />
      <RFOperationalDeckV39NavigationFusion />
    </>
  )
}

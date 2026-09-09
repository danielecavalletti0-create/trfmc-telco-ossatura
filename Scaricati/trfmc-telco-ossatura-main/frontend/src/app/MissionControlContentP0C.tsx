import { MissionControlHomeP0C } from './MissionControlHomeP0C'
import { MissionControlIntegrationRoomP0C } from './MissionControlIntegrationRoomP0C'
import { MissionControlPortalIndexP0C } from './MissionControlPortalIndexP0C'

export function MissionControlContentP0C() {
  return (
    <section className="trfmc-p0c-content" data-trfmc-p0c-mission-control-content="mounted">
      <div className="trfmc-p0c-content-head">
        <p>TRFMC P0C · Mission Control Content Promotion</p>
        <h2>Home · Integration Control Room · Portal Index</h2>
        <span>
          Primo contenuto P0 promosso nel portale React ufficiale. Questa sezione sostituisce il
          concetto di pagine pubbliche parallele con componenti governati e verificabili.
        </span>
      </div>

      <MissionControlHomeP0C />
      <MissionControlIntegrationRoomP0C />
      <MissionControlPortalIndexP0C />
    </section>
  )
}

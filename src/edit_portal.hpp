/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_EDIT_PORTAL_HPP_
#define SRC_EDIT_PORTAL_HPP_

namespace Alarmud {

/** Avvia thread HTTP interno (porta EDIT_API_PORT). Chiamare dopo boot_db. */
void edit_portal_init();

/** Elabora richieste API sul thread principale (game loop). */
void edit_portal_process_pending();

inline constexpr int kEditPortalStaffLevel = 57;
inline constexpr int kEditPortalLimitedLevel = 51;
/** Incrementare quando cambia l'API HTTP interna del portale edit. */
inline constexpr int kEditPortalApiVersion = 45;
inline constexpr const char kEditPortalApiVersionTag[] = "portal_api_version";

} // namespace Alarmud

#endif

/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_PSI_SKILL_MIGRATION_HPP_
#define SRC_PSI_SKILL_MIGRATION_HPP_

namespace Alarmud {

struct char_data;

/** Normalize PSI skill flags for existing PCs after rebalance / tier split. */
void migrate_psi_skills(struct char_data* ch);

} // namespace Alarmud

#endif /* SRC_PSI_SKILL_MIGRATION_HPP_ */

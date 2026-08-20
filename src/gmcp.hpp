/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __GMCP_HPP
#define __GMCP_HPP
/***************************  System  include ************************************/
/***************************  Local    include ************************************/
namespace Alarmud {

struct char_data;
struct descriptor_data;

#ifndef TELOPT_GMCP
#define TELOPT_GMCP 201
#endif

/* Strip telnet IAC (incl. GMCP negotiation) from an input buffer; returns new length. */
int gmcp_filter_buffer(struct descriptor_data* d, char* buf, int len);

/* Push char.vitals / char.base (and optional Client.GUI on first connect). */
void gmcp_send_all(struct char_data* ch);
void gmcp_send_vitals(struct char_data* ch);
void gmcp_send_base(struct char_data* ch);

/* Called from game_loop when a prompt is about to be shown. */
void gmcp_on_prompt(struct descriptor_data* d);

} // namespace Alarmud
#endif // __GMCP_HPP

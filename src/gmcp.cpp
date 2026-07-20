/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include <arpa/telnet.h>
#include <cstdio>
#include <cstring>
#include <unistd.h>

#include "comm.hpp"
#include "constants.hpp"
#include "gmcp.hpp"
#include "multiclass.hpp"
#include "structs.hpp"
#include "utils.hpp"

namespace Alarmud {

namespace {

constexpr const char* kNebbiePackageUrl =
    "https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-play-all.mpackage";
constexpr const char* kNebbiePackageVersion = "2.2.34";

int gmcp_write_raw(int desc, const void* data, size_t len) {
	if(desc < 0 || data == nullptr || len == 0) {
		return 0;
	}
	const char* bytes = static_cast<const char*>(data);
	size_t sofar = 0;
	while(sofar < len) {
		const ssize_t n = write(desc, bytes + sofar, len - sofar);
		if(n < 0) {
			return -1;
		}
		sofar += static_cast<size_t>(n);
	}
	return static_cast<int>(sofar);
}

void gmcp_send_negotiation(struct descriptor_data* d, unsigned char verb) {
	if(d == nullptr) {
		return;
	}
	const unsigned char resp[] = {static_cast<unsigned char>(IAC), verb,
	                              static_cast<unsigned char>(TELOPT_GMCP)};
	gmcp_write_raw(d->descriptor, resp, sizeof(resp));
}

void gmcp_json_escape(char* out, size_t outlen, const char* in) {
	size_t w = 0;
	if(outlen == 0) {
		return;
	}
	for(; in && *in && w + 2 < outlen; ++in) {
		const unsigned char c = static_cast<unsigned char>(*in);
		if(c == '"' || c == '\\') {
			out[w++] = '\\';
		}
		if(c == '\n' || c == '\r' || c == '\t') {
			continue;
		}
		out[w++] = static_cast<char>(c);
	}
	out[w] = '\0';
}

void gmcp_send_package(struct descriptor_data* d, const char* package, const char* json) {
	if(d == nullptr || !d->gmcp_enabled || package == nullptr || json == nullptr) {
		return;
	}
	char payload[MAX_STRING_LENGTH];
	const int n = snprintf(payload, sizeof(payload), "%s %s", package, json);
	if(n <= 0 || static_cast<size_t>(n) >= sizeof(payload)) {
		return;
	}

	unsigned char frame[MAX_STRING_LENGTH + 8];
	size_t pos = 0;
	frame[pos++] = static_cast<unsigned char>(IAC);
	frame[pos++] = static_cast<unsigned char>(SB);
	frame[pos++] = static_cast<unsigned char>(TELOPT_GMCP);
	memcpy(frame + pos, payload, static_cast<size_t>(n));
	pos += static_cast<size_t>(n);
	frame[pos++] = static_cast<unsigned char>(IAC);
	frame[pos++] = static_cast<unsigned char>(SE);
	gmcp_write_raw(d->descriptor, frame, pos);
}

const char* gmcp_primary_class(struct char_data* ch) {
	if(ch == nullptr) {
		return "";
	}
	const int idx = BestFightingClass(ch);
	if(idx < 0 || idx >= static_cast<int>(sizeof(pc_class_types) / sizeof(pc_class_types[0]))) {
		return "";
	}
	return pc_class_types[idx];
}

int gmcp_exp_to_next(struct char_data* ch) {
	if(ch == nullptr || IS_NPC(ch) || GetMaxLevel(ch) >= MAX_IMMORT) {
		return 0;
	}
	int best = 0;
	for(int i = MAGE_LEVEL_IND; i < MAX_CLASS; ++i) {
		if(!GET_LEVEL(ch, i)) {
			continue;
		}
		const int next_exp = titles[i][GET_LEVEL(ch, i) + 1].exp;
		const int delta = next_exp - GET_EXP(ch);
		if(delta > best) {
			best = delta;
		}
	}
	return best;
}

} // namespace

int gmcp_filter_buffer(struct descriptor_data* d, char* buf, int len) {
	if(d == nullptr || buf == nullptr || len <= 0) {
		return len;
	}

	int rd = 0;
	int wr = 0;
	while(rd < len) {
		const unsigned char c = static_cast<unsigned char>(buf[rd]);
		if(c != static_cast<unsigned char>(IAC)) {
			buf[wr++] = buf[rd++];
			continue;
		}
		if(rd + 1 >= len) {
			break;
		}
		const unsigned char cmd = static_cast<unsigned char>(buf[rd + 1]);
		if(cmd == static_cast<unsigned char>(IAC)) {
			buf[wr++] = static_cast<char>(IAC);
			rd += 2;
			continue;
		}
		if(cmd == static_cast<unsigned char>(SB)) {
			int se = rd + 2;
			for(; se + 1 < len; ++se) {
				if(static_cast<unsigned char>(buf[se]) == static_cast<unsigned char>(IAC) &&
				   static_cast<unsigned char>(buf[se + 1]) == static_cast<unsigned char>(SE)) {
					se += 2;
					break;
				}
			}
			if(se + 1 >= len && se < len) {
				break;
			}
			rd = se;
			continue;
		}
		if(rd + 2 >= len) {
			break;
		}
		const unsigned char opt = static_cast<unsigned char>(buf[rd + 2]);
		if(opt == static_cast<unsigned char>(TELOPT_GMCP)) {
			if(cmd == static_cast<unsigned char>(WILL)) {
				d->gmcp_enabled = true;
				gmcp_send_negotiation(d, static_cast<unsigned char>(DO));
			}
			else if(cmd == static_cast<unsigned char>(DO)) {
				d->gmcp_enabled = true;
				gmcp_send_negotiation(d, static_cast<unsigned char>(WILL));
			}
			else if(cmd == static_cast<unsigned char>(WONT) || cmd == static_cast<unsigned char>(DONT)) {
				d->gmcp_enabled = false;
			}
		}
		rd += 3;
	}

	if(rd < len) {
		memmove(buf + wr, buf + rd, static_cast<size_t>(len - rd));
		wr += len - rd;
	}
	buf[wr] = '\0';
	return wr;
}

void gmcp_send_vitals(struct char_data* ch) {
	if(ch == nullptr || ch->desc == nullptr || !ch->desc->gmcp_enabled || IS_NPC(ch)) {
		return;
	}
	char json[MAX_INPUT_LENGTH];
	snprintf(json, sizeof(json),
	         "{\"hp\":%d,\"maxhp\":%d,\"mana\":%d,\"maxmana\":%d,"
	         "\"move\":%d,\"maxmove\":%d,\"pow\":%d,\"maxpow\":%d}",
	         GET_HIT(ch), GET_MAX_HIT(ch), GET_MANA(ch), GET_MAX_MANA(ch),
	         GET_MOVE(ch), GET_MAX_MOVE(ch), GET_MOVE(ch), GET_MAX_MOVE(ch));
	gmcp_send_package(ch->desc, "char.vitals", json);
}

void gmcp_send_base(struct char_data* ch) {
	if(ch == nullptr || ch->desc == nullptr || !ch->desc->gmcp_enabled || IS_NPC(ch)) {
		return;
	}
	char name_esc[MAX_INPUT_LENGTH];
	gmcp_json_escape(name_esc, sizeof(name_esc), GET_NAME(ch));
	char json[MAX_STRING_LENGTH];
	snprintf(json, sizeof(json),
	         "{\"name\":\"%s\",\"class\":\"%s\",\"level\":%d,"
	         "\"experience\":%d,\"gold\":%d,\"toNext\":%d}",
	         name_esc, gmcp_primary_class(ch), GetMaxLevel(ch),
	         GET_EXP(ch), GET_GOLD(ch), gmcp_exp_to_next(ch));
	gmcp_send_package(ch->desc, "char.base", json);
}

void gmcp_send_client_gui(struct descriptor_data* d) {
	if(d == nullptr || !d->gmcp_enabled) {
		return;
	}
	char json[MAX_STRING_LENGTH];
	snprintf(json, sizeof(json),
	         "{\"url\":\"%s\",\"version\":\"%s\"}",
	         kNebbiePackageUrl, kNebbiePackageVersion);
	gmcp_send_package(d, "Client.GUI", json);
}

void gmcp_send_all(struct char_data* ch) {
	if(ch == nullptr || ch->desc == nullptr || !ch->desc->gmcp_enabled || IS_NPC(ch)) {
		return;
	}
	if(!ch->desc->gmcp_sent_login) {
		gmcp_send_client_gui(ch->desc);
		ch->desc->gmcp_sent_login = true;
	}
	gmcp_send_base(ch);
	gmcp_send_vitals(ch);
}

void gmcp_on_prompt(struct descriptor_data* d) {
	if(d == nullptr || d->character == nullptr || !d->gmcp_enabled ||
	   d->connected != CON_PLYNG || IS_NPC(d->character)) {
		return;
	}
	gmcp_send_vitals(d->character);
	gmcp_send_base(d->character);
}

} // namespace Alarmud

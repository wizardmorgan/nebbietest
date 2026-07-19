/* cacaodemon_summon_lexicon.inc
 *
 * Pool lessicali per identita procedurali del summon.
 * Temi: Angelic (good), Infernal (evil, nomi nuovi), Construct (neutral).
 */

#ifndef __CACAODEMON_SUMMON_LEXICON_INC
#define __CACAODEMON_SUMMON_LEXICON_INC

namespace Alarmud {

struct CacaoLexemePool {
	const char* const* items;
	int count;
};

#define CACAO_POOL(name, ...) \
	static const char* const name##_items[] = { __VA_ARGS__ }; \
	static const CacaoLexemePool name = { name##_items, \
		static_cast<int>(sizeof(name##_items) / sizeof(name##_items[0])) }

CACAO_POOL(kCacaoAngelPrefix,
	"Serafico", "Aureo", "Candido", "Luminoso", "Celeste", "Irideo", "Sacro", "Radioso");
CACAO_POOL(kCacaoAngelCore,
	"Custode", "Araldo", "Vigilante", "Cantore", "Scudiero", "Sentinella", "Messaggero", "Giudice");
CACAO_POOL(kCacaoAngelSuffix,
	"dell'Alba", "della Quiete", "del Voto", "delle Sfere", "dell'Empireo", "della Grazia",
	"del Sigillo", "della Luce");
CACAO_POOL(kCacaoAngelLook,
	"Ali di luce soffusa vibrano senza muovere l'aria.",
	"Occhi chiari riflettono costellazioni che non appartengono a questo cielo.",
	"Una corazza di metallo bianco emana un calore mite e costante.",
	"Rune dorate scorrono sulla pelle come scrittura viva.",
	"Un alone tenue disegna aureole incomplete intorno al capo.",
	"Le mani lasciano scie di polvere stellare che svanisce al suolo.");
CACAO_POOL(kCacaoAngelPresence,
	"Un essere di luce scende in un silenzio pieno di eco.",
	"L'aria si fa chiara mentre una figura alata prende forma.",
	"Un canto senza parole precede l'arrivo di una presenza sacra.",
	"Un bagliore bianco si addensa e diventa forma vivente.");
CACAO_POOL(kCacaoAngelSound,
	"Un rintocco lontano, come di campane di cristallo.",
	"Un soffio armonico attraversa la stanza.",
	"Un coro sommesso sembra provenire da nessuna direzione.");

CACAO_POOL(kCacaoInfernalPrefix,
	"Vorace", "Obsidiano", "Screziato", "Cremisi", "Torvo", "Cenere", "Vincolato", "Spezzato");
CACAO_POOL(kCacaoInfernalCore,
	"Devastatore", "Maciulla", "Catenafuoco", "Ombrafauce", "Rovina", "Piagatroce",
	"Sanguescudo", "Nottangolo");
CACAO_POOL(kCacaoInfernalSuffix,
	"del Patto Nero", "delle Braci", "dell'Abisso Chiuso", "della Faglia",
	"del Giogo", "delle Ceneri Vive", "del Sigillo Infranto", "della Fauce Lenta");
CACAO_POOL(kCacaoInfernalLook,
	"Corna irregolari inquadrano un volto senza empatia.",
	"Fiamme basse leccano piastre di ferro nero senza consumarle.",
	"Catene fumanti ruotano lente intorno al torso.",
	"Occhi di brace fissano attraverso il fumo come feritoie.",
	"La pelle e' un mosaico di cicatrici e rune di vincolo.",
	"Un odore di pece e metallo rovente anticipa ogni passo.");
CACAO_POOL(kCacaoInfernalPresence,
	"Una risata secca squarcia una nuvola di fumo nero.",
	"Il suolo scricchiola mentre una figura cornutta emerge dal buio.",
	"Braci sospese si addensano in una forma ostile.",
	"Un patto antico prende corpo in una silhouette di fiamma e ferro.");
CACAO_POOL(kCacaoInfernalSound,
	"Un ringhio metallico vibra nelle ossa.",
	"Catene si trascinano su pietra invisibile.",
	"Un crepitio di brace accompagna ogni respiro.");

CACAO_POOL(kCacaoConstructPrefix,
	"Adamantino", "Basaltico", "Runico", "Temperato", "Quarzoso", "Ferrato", "Sigillato", "Arcano");
CACAO_POOL(kCacaoConstructCore,
	"Golem", "Automa", "Colosso", "Presidio", "Nucleo", "Baluardo", "Ordigno", "Simulacro");
CACAO_POOL(kCacaoConstructSuffix,
	"di Argilla", "di Bronzo", "di Pietra Legata", "di Cristallo Morto",
	"di Ferro Freddo", "di Ossidiana", "di Rune Mute", "di Ingegno Antico");
CACAO_POOL(kCacaoConstructLook,
	"Giunture di pietra scricchiolano con precisione innaturale.",
	"Un nucleo luminoso pulsa dietro una grata di metallo.",
	"Rune spente scorrono lungo piastre senza calore.",
	"Occhi di quarzo ruotano a scatti, cercando minacce.",
	"Polvere di pietra cade dai gomiti a ogni movimento.",
	"Il torso e' un assemblaggio di lastre e sigilli meccanici.");
CACAO_POOL(kCacaoConstructPresence,
	"Pietra e metallo si assemblano in una sagoma silenziosa.",
	"Un ronzio basso precede l'attivazione di un costrutto.",
	"Polvere e schegge orbitano e poi si compongono in forma.",
	"Un telaio runico si alza dal nulla come un ordigno sveglio.");
CACAO_POOL(kCacaoConstructSound,
	"Un ticchettio di meccanismi interni.",
	"Una vibrazione di pietra contro pietra.",
	"Un ronzio monotono, quasi meditativo.");

#undef CACAO_POOL

} // namespace Alarmud

#endif

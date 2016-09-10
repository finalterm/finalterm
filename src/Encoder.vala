/*
 * Copyright © 2013–2014 Philipp Emanuel Weidmann <pew@worldwidemann.com>
 * Copyright © 2015-2016 RedHatter <timothy@idioticdev.com>
 *
 * Nemo vir est qui mundum non reddat meliorem.
 *
 *
 * This file is part of Final Term.
 *
 * Final Term is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Final Term is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Encoder : Object {
	public enum Charset {
		DEC_SPECIAL,
		DEC_SUPPLEMENTARY_GRAPHICS,
		DEC_TECHNICAL,
		UNITED_KINGDOM,
		UNITED_STATES,
		DUTCH,
		FINNISH,
		FRENCH,
		FRENCH_CANADIAN,
		GERMAN,
		ITALIAN,
		NORWEGIAN_DANISH,
		PORTUGUESE,
		SPANISH,
		SWEDISH,
		SWISS,
	}

	public Charset[] charsets = {
		Charset.UNITED_STATES,
		Charset.UNITED_STATES,
		Charset.UNITED_STATES,
		Charset.UNITED_STATES
	};
	public int gl = 0;
	public int single_shift = -1;

	private void copy_method(Encoder encoder) {
		gl = encoder.gl;
		single_shift = encoder.single_shift;
		charsets = encoder.charsets;
	}

	public Encoder.copy(Encoder encoder) {
		copy_method(encoder);
	}

	/**
	 *  TODO:
	 *   Portuguese is unimplemented.
	 *   DEC Supplementary Graphics and DEC Supplementary are the same?
	 */
	public bool setCharset (int g, string selector) {
		switch (selector) {
			case "0":
				charsets[g] = Charset.DEC_SPECIAL;
				break;
			case "<":
			case "%5":
				charsets[g] = Charset.DEC_SUPPLEMENTARY_GRAPHICS;
				break;
			case ">":
				charsets[g] = Charset.DEC_TECHNICAL;
				break;
			case "A":
				charsets[g] = Charset.UNITED_KINGDOM;
				break;
			case "B":
				charsets[g] = Charset.UNITED_STATES;
				break;
			case "4":
				charsets[g] = Charset.DUTCH;
				break;
			case "C":
			case "5":
				charsets[g] = Charset.FINNISH;
				break;
			case "R":
			case "f":
				charsets[g] = Charset.FRENCH;
				break;
			case "Q":
			case "9":
				charsets[g] = Charset.FRENCH_CANADIAN;
				break;
			case "K":
				charsets[g] = Charset.GERMAN;
				break;
			case "Y":
				charsets[g] = Charset.ITALIAN;
				break;
			case "`":
			case "E":
			case "6":
				charsets[g] = Charset.NORWEGIAN_DANISH;
				break;
			case "%6":
				charsets[g] = Charset.PORTUGUESE;
				break;
			case "Z":
				charsets[g] = Charset.SPANISH;
				break;
			case "H":
			case "7":
				charsets[g] = Charset.SWEDISH;
				break;
			case "=":
				charsets[g] = Charset.SWISS;
				break;
			default:
				return false;
		}

		return true;
	}

	public string encode (string text) {
		if (charsets[gl] == Charset.UNITED_STATES && single_shift == -1)
			return text;

		var result = new StringBuilder();
		for (int i = 0; i < text.length; i++) {
			if (!text.valid_char (i))
				continue;

			var c = text.get_char(i);
			var g = gl;
			if (single_shift != -1) {
				g = single_shift;
				single_shift = -1;
			}

			switch (charsets[g]) {
				case Charset.DEC_SUPPLEMENTARY_GRAPHICS:
					result.append_unichar(encode_dec_supplementary_graphics(c));
					break;
				case Charset.DEC_SPECIAL:
					result.append_unichar(encode_dec_special(c));
					break;
				case Charset.DEC_TECHNICAL:
					result.append_unichar(encode_dec_technical(c));
					break;
				case Charset.UNITED_KINGDOM:
					result.append_unichar(encode_united_kingdom(c));
					break;
				case Charset.NORWEGIAN_DANISH:
					result.append_unichar(encode_norwegian_danish(c));
					break;
				case Charset.DUTCH:
					result.append_unichar(encode_dutch(c));
					break;
				case Charset.FINNISH:
					result.append_unichar(encode_finnish(c));
					break;
				case Charset.FRENCH:
					result.append_unichar(encode_french(c));
					break;
				case Charset.FRENCH_CANADIAN:
					result.append_unichar(encode_french_canadian(c));
					break;
				case Charset.GERMAN:
					result.append_unichar(encode_german(c));
					break;
				case Charset.ITALIAN:
					result.append_unichar(encode_italian(c));
					break;
				case Charset.SPANISH:
					result.append_unichar(encode_spanish(c));
					break;
				case Charset.SWEDISH:
					result.append_unichar(encode_swedish(c));
					break;
				case Charset.SWISS:
					result.append_unichar(encode_swiss(c));
					break;
				case Charset.PORTUGUESE:
					result.append_unichar(encode_portuguese(c));
					break;
				default:
					result.append_unichar(c);
					break;
			}
		}

		return result.str;
	}

	unichar encode_portuguese (unichar c) {
		switch (c) {
			case '[': return 0x00C3;
			case '\\': return 0x00C7;
			case ']': return 0x00D5;
			case '{': return 0x00E3;
			case '|': return 0x00E7;
			case '}': return 0x00F5;
			default: return c;
		}
	}

	unichar encode_swiss (unichar c) {
		switch (c) {
			case '#': return 0x00f9;
			case '@': return 0x00e0;
			case '[': return 0x00e9;
			case '\\': return 0x00e7;
			case ']': return 0x00ea;
			case '^': return 0x00ee;
			case '_': return 0x00e8;
			case '`': return 0x00f4;
			case '{': return 0x00e4;
			case '|': return 0x00fc;
			case '}': return 0x00e5;
			case '~': return 0x00fb;
			default: return c;
		}
	}

	unichar encode_swedish (unichar c) {
		switch (c) {
			case '@': return 0x00c9;
			case '[': return 0x00c4;
			case '\\': return 0x00d6;
			case ']': return 0x00c5;
			case '^': return 0x00dc;
			case '{': return 0x00e4;
			case '|': return 0x00f6;
			case '}': return 0x00e5;
			case '~': return 0x00fc;
			default: return c;
		}
	}

	unichar encode_spanish (unichar c) {
		switch (c) {
			case '#': return 0x00a3;
			case '@': return 0x00a7;
			case '[': return 0x00a1;
			case '\\': return 0x00d1;
			case ']': return 0x00bf;
			case '{': return 0x00b0;
			case '|': return 0x00f1;
			case '}': return 0x00e7;
			default: return c;
		}
	}

	unichar encode_italian (unichar c) {
		switch (c) {
			case '#': return 0x00a3;
			case '@': return 0x00a7;
			case '[': return 0x00b0;
			case '\\': return 0x00e7;
			case ']': return 0x00e9;
			case '`': return 0x00f9;
			case '{': return 0x00e0;
			case '|': return 0x00f2;
			case '}': return 0x00e8;
			case '~': return 0x00ec;
			default: return c;
		}
	}

	unichar encode_german (unichar c) {
		switch (c) {
			case '@': return 0x00a7;
			case '[': return 0x00c4;
			case '\\': return 0x00d6;
			case ']': return 0x00dc;
			case '{': return 0x00e4;
			case '|': return 0x00f6;
			case '}': return 0x00fc;
			case '~': return 0x00df;
			default: return c;
		}
	}

	unichar encode_french_canadian (unichar c) {
		switch (c) {
			case '@': return 0x00e0;
			case '[': return 0x00e2;
			case '\\': return 0x00e7;
			case ']': return 0x00ea;
			case '^': return 0x00ee;
			case '`': return 0x00f4;
			case '{': return 0x00e9;
			case '|': return 0x00f9;
			case '}': return 0x00e8;
			case '~': return 0x00fb;
			default: return c;
		}
	}

	unichar encode_french (unichar c) {
		switch (c) {
			case '#': return 0x00a3;
			case '@': return 0x00e0;
			case '[': return 0x00b0;
			case '\\': return 0x00e7;
			case ']': return 0x00a7;
			case '{': return 0x00e9;
			case '|': return 0x00f9;
			case '}': return 0x00e8;
			case '~': return 0x00a8;
			default: return c;
		}
	}

	unichar encode_finnish (unichar c) {
		switch (c) {
			case '[': return 0x00c4;
			case '\\': return 0x00d6;
			case ']': return 0x00c5;
			case '^': return 0x00dc;
			case '`': return 0x00e9;
			case '{': return 0x00e4;
			case '|': return 0x00f6;
			case '}': return 0x00e5;
			case '~': return 0x00fc;
			default: return c;
		}
	}

	unichar encode_norwegian_danish (unichar c) {
		switch (c) {
			case '@': return 0x00c4;
			case '[': return 0x00c6;
			case '\\': return 0x00d8;
			case ']': return 0x00c5;
			case '^': return 0x00dc;
			case '{': return 0x00e6;
			case '|': return 0x00f8;
			case '}': return 0x00e5;
			case '~': return 0x00fc;
			default: return c;
		}
	}

	unichar encode_dutch (unichar c) {
		switch (c) {
			case '#': return 0x00a3;
			case '@': return 0x00be;
			case '[': return 0x0133;
			case '\\': return 0x00bd;
			case ']': return '|';
			case '{': return 0x00a8;
			case '|': return 'f';
			case '}': return 0x00bc;
			case '~': return 0x00b4;
			default: return c;
		}
	}

	unichar encode_united_kingdom (unichar c) {
		switch (c) {
			case '#': return 0x00a3;
			default: return c;
		}
	}

	unichar[] dec_special = new unichar[] {
		0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a,
		0x00b0, 0x00b1, 0x2424, 0x240b, 0x2518, 0x2510,
		0x250c, 0x2514, 0x253c, 0x23ba, 0x23bb, 0x2500,
		0x23bc, 0x23bd, 0x251c, 0x2524, 0x2534, 0x252c,
		0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3,
		0x00b7
	};
	unichar encode_dec_special (unichar c) {
		var d = (int) c;
		if (95 < d < 127) return dec_special[d - 96];

		return c;
	}

	unichar[] dec_technical = new unichar[] {
		0x23B7, 0x250C, 0x2500, 0x2320, 0x2321, 0x2502,
		0x23A1, 0x23A3, 0x23A4, 0x23A6, 0x239B, 0x239D,
		0x239E, 0x23A0, 0x23A8, 0x23AC, 0x2426, 0x2426,
		0x2426, 0x2426, 0x2426, 0x2426, 0x2426, 0x2426,
		0x2426, 0x2426, 0x2426, 0x2264, 0x2260, 0x2265,
		0x222B, 0x2234, 0x221D, 0x221E, 0x00F7, 0x039A,
		0x2207, 0x03A6, 0x0393, 0x223C, 0x2243, 0x0398,
		0x00D7, 0x039B, 0x21D4, 0x21D2, 0x2261, 0x03A0,
		0x03A8, 0x2426, 0x03A3, 0x2426, 0x2426, 0x221A,
		0x03A9, 0x039E, 0x03A5, 0x2282, 0x2283, 0x2229,
		0x222A, 0x2227, 0x2228, 0x00AC, 0x03B1, 0x03B2,
		0x03C7, 0x03B4, 0x03B5, 0x03C6, 0x03B3, 0x03B7,
		0x03B9, 0x03B8, 0x03BA, 0x03BB, 0x2426, 0x03BD,
		0x2202, 0x03C0, 0x03C8, 0x03C1, 0x03C3, 0x03C4,
		0x2426, 0x0192, 0x03C9, 0x03BE, 0x03C5, 0x03B6,
		0x2190, 0x2191, 0x2192, 0x2193
	};
	unichar encode_dec_technical (unichar c) {
		return dec_technical[((int) c) - 32];
	}

	unichar encode_dec_supplementary_graphics (unichar c) {
		switch (c) {
			case '!': return 0x00a1;
			case '"': return 0x00a2;
			case '#': return 0x00a3;
			case '%': return 0x00a5;
			case '\'': return 0x00a7;
			case '(': return 0x00a4;
			case ')': return 0x00a9;
			case '*': return 0x00aa;
			case '+': return 0x00ab;

			case '0': return 0x00b0;
			case '1': return 0x00b1;
			case '2': return 0x00b2;
			case '3': return 0x00b3;
			case '5': return 0x00b5;
			case '6': return 0x00b6;
			case '7': return 0x00b7;
			case '9': return 0x00b9;
			case ':': return 0x00ba;
			case ';': return 0x00bb;
			case '<': return 0x00bc;
			case '=': return 0x00bd;
			case '?': return 0x00bf;

			case '@': return 0x00c0;
			case 'A': return 0x00c1;
			case 'B': return 0x00c2;
			case 'C': return 0x00c3;
			case 'D': return 0x00c4;
			case 'E': return 0x00c5;
			case 'F': return 0x00c6;
			case 'G': return 0x00c7;
			case 'H': return 0x00c8;
			case 'I': return 0x00c9;
			case 'J': return 0x00ca;
			case 'K': return 0x00cb;
			case 'L': return 0x00cc;
			case 'M': return 0x00cd;
			case 'N': return 0x00ce;
			case 'O': return 0x00cf;

			case 'Q': return 0x00d1;
			case 'R': return 0x00d2;
			case 'S': return 0x00d3;
			case 'T': return 0x00d4;
			case 'U': return 0x00d5;
			case 'V': return 0x00d6;
			case 'W': return 0x0152;
			case 'X': return 0x00d8;
			case 'Y': return 0x00d9;
			case 'Z': return 0x00da;
			case '[': return 0x00db;
			case '\\': return 0x00dc;
			case ']': return 0x0178;
			case '_': return 0x00df;

			case '`': return 0x00e0;
			case 'a': return 0x00e1;
			case 'b': return 0x00e2;
			case 'c': return 0x00e3;
			case 'd': return 0x00e4;
			case 'e': return 0x00e5;
			case 'f': return 0x00e6;
			case 'g': return 0x00e7;
			case 'h': return 0x00e8;
			case 'i': return 0x00e9;
			case 'j': return 0x00ea;
			case 'k': return 0x00eb;
			case 'l': return 0x00ec;
			case 'm': return 0x00ed;
			case 'n': return 0x00ee;
			case 'o': return 0x00ef;

			case 'q': return 0x00f1;
			case 'r': return 0x00f2;
			case 's': return 0x00f3;
			case 't': return 0x00f4;
			case 'u': return 0x00f5;
			case 'v': return 0x00f6;
			case 'w': return 0x0153;
			case 'x': return 0x00f8;
			case 'y': return 0x00f9;
			case 'z': return 0x00fa;
			case '{': return 0x00fb;
			case '|': return 0x00fc;
			case '}': return 0x00ff;
			default: return c;
		}
	}
}

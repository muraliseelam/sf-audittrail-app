/**
 * CSV helpers for the audit export.
 *
 * Kept out of the component so the escaping rules - which are a security
 * control, not just formatting - can be tested directly.
 */

// Excel and Google Sheets treat a leading =, +, -, @ (or a leading tab/CR) as
// the start of a formula. Audit descriptions echo text an admin controls, such
// as renamed field labels, so an exported cell could otherwise carry a payload
// that executes on the auditor's machine when the file is opened.
//
// Leading whitespace is included because some importers trim before evaluating,
// which would expose a trigger character that was not at position zero in the
// raw value.
//
// Full-width variants of the same four characters (＝ ＋ － ＠, U+FF1D/FF0B/
// FF0D/FF20) are included too: some spreadsheet/IME environments normalize
// full-width punctuation to its ASCII equivalent on paste or import, so a
// value that is harmless as stored (a distinct code point, not a formula
// trigger to a naive scanner) could still be interpreted as a formula once
// normalized. They are detected exactly like their ASCII counterparts - only
// at position zero, only to decide whether to prepend the same single quote -
// so no exported display text is altered beyond that, full-width or not.
const FORMULA_TRIGGER = /^[\s=+\-@\uFF1D\uFF0B\uFF0D\uFF20]/;

// Characters \s does not match but that an importer may still strip before it
// evaluates the cell: C0 control codes and the zero-width space. The remaining
// exotic spaces (NBSP, en/em spaces, BOM) are already covered by \s. Tested by
// code point rather than by a regex character class, because a control
// character inside a regex literal is itself a readability hazard.
const ZERO_WIDTH_SPACE = 0x200b;

function startsWithStrippableChar(text) {
    const code = text.charCodeAt(0);
    return code <= 0x1f || code === ZERO_WIDTH_SPACE;
}

export function csvCell(value) {
    if (value === null || value === undefined) {
        return '""';
    }
    let text = String(value);
    if (text.length > 0 && (FORMULA_TRIGGER.test(text) || startsWithStrippableChar(text))) {
        text = `'${text}`;
    }
    return `"${text.replace(/"/g, '""')}"`;
}

export function csvRow(values) {
    return values.map(csvCell).join(',');
}

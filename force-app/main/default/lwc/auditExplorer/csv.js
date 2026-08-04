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
const FORMULA_TRIGGER = /^[=+\-@\t\r]/;

export function csvCell(value) {
    if (value === null || value === undefined) {
        return '""';
    }
    let text = String(value);
    if (FORMULA_TRIGGER.test(text)) {
        text = `'${text}`;
    }
    return `"${text.replace(/"/g, '""')}"`;
}

export function csvRow(values) {
    return values.map(csvCell).join(',');
}

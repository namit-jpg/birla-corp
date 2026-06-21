/**
 * Shared helpers for full-width auto-sizing lightning-datatable usage.
 */
export function autoColumns(columns) {
    return (columns || []).map(col => {
        const { initialWidth, fixedWidth, ...rest } = col;
        return rest;
    });
}

export function decorateRows(rows, mapper) {
    return (rows || []).map(mapper);
}

export function countLabel(shown, total, noun = 'records') {
    if (!total) return `0 ${noun}`;
    if (shown === total) return `${total} ${noun}`;
    return `${shown} of ${total} ${noun} shown`;
}

export const LENGTH_ENUM = {
  hours: 'HOURS',
  days: 'DAYS',
  weeks: 'WEEKS',
};

export const CHEVRON_SKIPPING_SHADE_ENUM = ['500', '600', '700', '800', '900', '950'];

export const CHEVRON_SKIPPING_PALETTE_ENUM = ['blue', 'orange', 'aqua', 'green', 'magenta'];

/**
 * an Array of Objects that represent the 30 possible
 * color combinations for assignees
 * @type {{colorWeight: string, colorPalette: string}[]}
 */
export const ASSIGNEE_COLORS_COMBO = CHEVRON_SKIPPING_SHADE_ENUM.map((shade) =>
  CHEVRON_SKIPPING_PALETTE_ENUM.map((color) => ({
    // eslint-disable-next-line @gitlab/require-i18n-strings
    colorWeight: `WEIGHT_${shade.toUpperCase()}`,
    colorPalette: color.toUpperCase(),
  })),
).flat();

export const DAYS_IN_WEEK = 7;
export const HOURS_IN_DAY = 24;

export const PRESET_TYPES = {
  DAYS: 'DAYS',
  WEEKS: 'WEEKS',
};

export const PRESET_DEFAULTS = {
  WEEKS: {
    TIMEFRAME_LENGTH: 2,
  },
};

export const addRotationModalId = 'addRotationModal';
export const editRotationModalId = 'editRotationModal';
export const deleteRotationModalId = 'deleteRotationModal';

export const ASSIGNEE_SPACER = 2;
export const ASSIGNEE_SPACER_SMALL = 1;
export const TIMELINE_CELL_WIDTH = 180;
export const SHIFT_WIDTH_CALCULATION_DELAY = 250;
export const CURRENT_DAY_INDICATOR_OFFSET = 2.25;

export const oneHourOffsetDayView = 100 / HOURS_IN_DAY;
export const oneDayOffsetWeekView = 100 / DAYS_IN_WEEK;
export const oneHourOffsetWeekView = oneDayOffsetWeekView / HOURS_IN_DAY;

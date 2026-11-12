import type { VaultCategory } from '~/types/ayla';

/** The categories of vault_items, as in the database. "other" (Overige) came with the second vault migration. */
export type VaultItemCategory = VaultCategory | 'other';

export type VaultAddStep = 'basis' | 'details' | 'cover' | 'skills' | 'done';

/** A month as `YYYY-MM`, the value of an `<input type="month">`. Empty when not filled in. */
export type VaultMonth = string;

export interface VaultItemDraft {
  title: string;
  category: VaultItemCategory | '';
  organisationName: string;
  startMonth: VaultMonth;
  endMonth: VaultMonth;
  issuedMonth: VaultMonth;
  description: string;
}

export type VaultCoverChoice = 'none' | 'cover';

export interface VaultSkillOption {
  name: string;
  isSelected: boolean;
}

import type { Vacancy, VacancySalary } from '~/types/ayla';
import { AYLA_FULL_TIME, AYLA_PART_TIME } from './aylaMessages';

const MONTHS_PER_YEAR = 12;
const EURO_FORMAT = new Intl.NumberFormat('nl-NL', { maximumFractionDigits: 0 });

function toMonthly(amount: number, period: VacancySalary['period']) {
  if (period === 'year') return Math.round(amount / MONTHS_PER_YEAR);
  return Math.round(amount);
}

/** "€2.800 - €3.400 p/m", with "(geschat)" for an estimate. A yearly salary is shown per month (same as iOS). */
export function formatMonthlySalary(salary: VacancySalary) {
  const min = EURO_FORMAT.format(toMonthly(salary.min, salary.period));
  const max = EURO_FORMAT.format(toMonthly(salary.max, salary.period));
  const range = min === max ? `€${min} p/m` : `€${min} - €${max} p/m`;
  if (salary.isEstimate) return `${range} (geschat)`;
  return range;
}

export function getEmploymentText(employment: Vacancy['employment']) {
  if (employment === 'fullTime') return AYLA_FULL_TIME;
  if (employment === 'partTime') return AYLA_PART_TIME;
  return null;
}

export function getCompanyLine(vacancy: Vacancy) {
  const parts = [vacancy.company, vacancy.city].filter(Boolean);
  return parts.join(' - ');
}

export function getMonogram(company: string) {
  return company.trim().charAt(0).toUpperCase();
}

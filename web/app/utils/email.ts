const MASK = '***';

export function maskEmail(email: string) {
  const [localPart, domain] = email.trim().split('@');
  if (!localPart || !domain) return email;
  return `${localPart.charAt(0)}${MASK}@${domain}`;
}

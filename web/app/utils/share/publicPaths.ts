/** Pages anyone can open without an account: a shared profile, an employer at a fair, and the fair. */
export function isPublicSharePath(path: string): boolean {
  return path === '/beurs' || path.startsWith('/gedeeld/') || path.startsWith('/werkgever/');
}

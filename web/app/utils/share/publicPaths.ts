/** Pages anyone can open without an account: a shared profile, an employer at a fair, the fair, and an employer's
 * inbox of the fair demo (behind its secret key). */
export function isPublicSharePath(path: string): boolean {
  return path === '/beurs' || path.startsWith('/gedeeld/') || path.startsWith('/werkgever/') || path.startsWith('/inbox/');
}

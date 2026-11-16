import assert from 'node:assert/strict'
import { test } from 'node:test'
import { PROPOSAL_MINUTES, vaultProposal } from '../proposal.ts'

const now = new Date('2026-11-11T10:00:00Z')

test('a stage the user named becomes a proposal with only what they said', () => {
  const action = vaultProposal(
    { category: 'internships', title: ' Stage   bij LiveWall ', organisation: 'LiveWall', place: 'Tilburg', startDate: '2025-03', endDate: '2025-12-31', issuedOn: null, isCurrent: false },
    'a1',
    now,
  )
  assert.ok(action)
  assert.equal(action.kind, 'addVaultItem')
  assert.equal(action.summary, 'Stage bij LiveWall in je kluis zetten bij Stages')
  assert.equal(action.expiresAt, new Date(now.getTime() + PROPOSAL_MINUTES * 60_000).toISOString())
  assert.deepEqual(action.vaultItem, {
    category: 'internships',
    title: 'Stage bij LiveWall',
    organisationName: 'LiveWall',
    organisationLocation: 'Tilburg',
    startDate: '2025-03-01',
    endDate: '2025-12-31',
  })
})

test('nothing usable means no proposal', () => {
  assert.equal(vaultProposal(null, 'a', now), undefined)
  assert.equal(vaultProposal({ category: 'pets', title: 'Hond' }, 'a', now), undefined)
  assert.equal(vaultProposal({ category: 'projects', title: '   ' }, 'a', now), undefined)
})

test('dates that do not exist or run backwards are left out', () => {
  const action = vaultProposal({ category: 'projects', title: 'App', startDate: '2025-06-01', endDate: '2025-02-01', issuedOn: '2025-02-30' }, 'a', now)
  assert.deepEqual(action?.vaultItem, { category: 'projects', title: 'App', startDate: '2025-06-01' })
})

test('still going means no end date', () => {
  const action = vaultProposal({ category: 'workExperience', title: 'Teamleider', startDate: '2025-11', endDate: '2026-01', isCurrent: true }, 'a', now)
  assert.deepEqual(action?.vaultItem, { category: 'workExperience', title: 'Teamleider', startDate: '2025-11-01', isCurrent: true })
})

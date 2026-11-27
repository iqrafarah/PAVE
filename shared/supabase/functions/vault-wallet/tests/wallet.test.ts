import assert from 'node:assert/strict'
import { test } from 'node:test'
import { itemRow, POOL, sameEvidence, walletFor } from '../wallet.ts'

const accounts = ['3f2b8c1e-5d4a-4f6b-9a7c-1e2d3c4b5a69', 'a1b2c3d4-0000-4000-8000-000000000001', '9e8d7c6b-1111-4222-8333-444455556666']

test('every account gets the same five credentials every time: a diploma, a certificate, two badges and an experience', () => {
  for (const account of accounts) {
    const wallet = walletFor(account)
    assert.deepEqual(walletFor(account.toUpperCase()), wallet)
    assert.deepEqual(wallet.slice(0, 4).map((c) => c.category), ['diplomas', 'certificates', 'badges', 'badges'])
    assert.ok(['internships', 'workExperience'].includes(wallet[4].category))
    assert.equal(new Set(wallet.map((c) => c.id)).size, 5)
  }
})

test('different accounts get different wallets', () => {
  const wallets = new Set(Array.from({ length: 30 }, (_, i) => walletFor(`00000000-0000-4000-8000-${String(i).padStart(12, '0')}`).map((c) => c.id).join()))
  assert.ok(wallets.size > 15)
})

test('the pool is complete and fits the vault', () => {
  const ids = POOL.map((c) => c.id)
  assert.equal(new Set(ids).size, ids.length)
  for (const credential of POOL) {
    assert.ok(credential.title.length <= 200 && credential.issuer.length <= 200, credential.id)
    assert.ok(credential.skills.length >= 1 && credential.skills.length <= 5, credential.id)
    assert.ok(credential.issuedOn || credential.startDate, credential.id)
    // A period that is still going has no end; a finished one ends after it started.
    assert.ok(!(credential.isCurrent && credential.endDate), credential.id)
    if (credential.startDate && credential.endDate) assert.ok(credential.endDate > credential.startDate, credential.id)
  }
})

test('an imported credential is a confirmed import in the vault, and is found again by title and institution', () => {
  const credential = POOL.find((c) => c.id === 'internship-frontend')!
  const row = itemRow(credential, 'user-1')
  assert.equal(row.verification_status, 'verified')
  assert.equal(row.source, 'import')
  assert.equal(row.organisation_name, 'Studio Noord')
  assert.equal(row.issued_on, null)
  assert.equal(row.start_date, '2025-02-03')
  assert.ok(sameEvidence(credential, { title: ' stage front-end development', organisation_name: 'studio noord' }))
  assert.equal(sameEvidence(credential, { title: 'Stage front-end development', organisation_name: 'Ander bedrijf' }), false)
})

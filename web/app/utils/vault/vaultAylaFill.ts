import type {
  VaultEvidenceBox,
  VaultEvidenceDocument,
  VaultEvidenceProposal,
  VaultEvidenceSourceField,
  VaultItemCategory,
  VaultItemDraft,
} from '~/types/vault';
import type { AylaVaultItemProposal } from '~/types/ayla';
import { isPdf, isText, readPdf, readPhoto } from '~/utils/vault/vaultSkillsMaterial';

// "Laat Ayla invullen" on the device (iOS VaultEvidenceReader, VaultAddEvidenceModel+Fill): the documents are read here,
// only after the user asked for it, and Ayla's proposal is put into the form. She fills in only what the documents say.

// Large enough for Ayla to point at a logo in the corner of a page.
const IMAGE_SIDE = 1400;
const MAXIMUM_TEXT = 8000;
const MAXIMUM_TITLE = 200;
const MAXIMUM_DESCRIPTION = 1200;

export interface VaultEvidenceReading {
  documents: VaultEvidenceDocument[];
}

/** One entry per chosen file, in the same order, so Ayla's numbers point at the right file. */
export async function readEvidence(files: File[]): Promise<VaultEvidenceReading> {
  const documents: VaultEvidenceDocument[] = [];
  for (const file of files) {
    const document: VaultEvidenceDocument = { name: file.name };
    if (isPdf(file)) {
      const read = await readPdf(file, { side: IMAGE_SIDE, alwaysPhoto: true });
      if (read?.text) document.text = read.text;
      if (read?.photo) document.image = read.photo;
    } else if (isText(file)) {
      const text = (await file.text().catch(() => '')).trim().slice(0, MAXIMUM_TEXT);
      if (text) document.text = text;
    } else if (file.type.startsWith('image/')) {
      const image = await readPhoto(file, IMAGE_SIDE);
      if (image) document.image = image;
    }
    documents.push(document);
  }
  return { documents };
}

/** `YYYY-MM-DD` as the month an `<input type="month">` takes. */
function month(day: string | null) {
  return day && /^\d{4}-\d{2}/.test(day) ? day.slice(0, 7) : '';
}

/** The draft with what Ayla found; what she did not find stays empty (iOS VaultEvidenceProposal.applied). */
export function applyProposal(proposal: VaultEvidenceProposal, draft: VaultItemDraft): VaultItemDraft {
  const result: VaultItemDraft = {
    ...draft,
    category: proposal.category,
    title: proposal.title.slice(0, MAXIMUM_TITLE),
    organisationName: proposal.organisationName ?? '',
    description: (proposal.description ?? '').slice(0, MAXIMUM_DESCRIPTION),
    startMonth: '',
    endMonth: '',
    issuedMonth: '',
    usesPeriod: null,
  };
  if (proposal.startDate) {
    result.usesPeriod = true;
    result.startMonth = month(proposal.startDate);
    result.endMonth = proposal.isCurrent ? '' : month(proposal.endDate);
  } else if (proposal.issuedOn) {
    result.usesPeriod = false;
    result.issuedMonth = month(proposal.issuedOn);
  }
  return result;
}

export type FilledField = VaultEvidenceSourceField;

/** The fields Ayla filled in, so the form can say so. */
export function filledFields(proposal: VaultEvidenceProposal): FilledField[] {
  const fields: FilledField[] = [];
  if (proposal.title) fields.push('title');
  if (proposal.organisationName) fields.push('organisation');
  if (proposal.startDate || proposal.issuedOn) fields.push('period');
  if (proposal.description) fields.push('description');
  return fields;
}

/** Whether a field is still as Ayla left it, so her note disappears once you change it. */
export function isSameField(field: FilledField, draft: VaultItemDraft, filled: VaultItemDraft) {
  switch (field) {
    case 'title':
      return draft.title === filled.title;
    case 'organisation':
      return draft.organisationName === filled.organisationName;
    case 'period':
      return (
        draft.usesPeriod === filled.usesPeriod &&
        draft.startMonth === filled.startMonth &&
        draft.endMonth === filled.endMonth &&
        draft.issuedMonth === filled.issuedMonth
      );
    case 'description':
      return draft.description === filled.description;
  }
}

/** The notes ("Door Ayla · pagina 1") for the fields that are still as she filled them in. */
export function aylaNotes(proposal: VaultEvidenceProposal | null, draft: VaultItemDraft, filled: VaultItemDraft | null) {
  const notes: Partial<Record<FilledField, string>> = {};
  if (!proposal || !filled) return notes;
  for (const field of filledFields(proposal)) {
    if (isSameField(field, draft, filled)) notes[field] = VAULT_FILLED_BY_AYLA(proposal.sources[field] ?? null);
  }
  return notes;
}

/** The documents of a proposal counted again within `indexes`, the documents it keeps. */
export function renumbered(proposal: VaultEvidenceProposal, indexes: number[]): VaultEvidenceProposal {
  const position = (index: number | null) => {
    const found = index === null ? -1 : indexes.indexOf(index);
    return found === -1 ? null : found;
  };
  return {
    ...proposal,
    documents: indexes.map((_, order) => order),
    coverDocument: position(proposal.coverDocument),
    logoDocument: position(proposal.logoDocument),
  };
}

function load(source: string) {
  return new Promise<HTMLImageElement | null>((resolve) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => resolve(null);
    image.src = source;
  });
}

function toFile(canvas: HTMLCanvasElement, name: string, type: string) {
  return new Promise<File | null>((resolve) =>
    canvas.toBlob((blob) => resolve(blob ? new File([blob], name, { type }) : null), type, type === 'image/jpeg' ? 0.9 : undefined),
  );
}

/** The part of a picture Ayla pointed at; without a box the whole picture. */
async function cut(base64: string, box: VaultEvidenceBox | null, name: string) {
  const image = await load(`data:image/jpeg;base64,${base64}`);
  if (!image) return null;
  const fraction = (value: number) => Math.min(1, Math.max(0, value));
  const x = box ? fraction(box.x) * image.naturalWidth : 0;
  const y = box ? fraction(box.y) * image.naturalHeight : 0;
  const width = Math.max(1, Math.round(box ? fraction(box.width) * image.naturalWidth : image.naturalWidth));
  const height = Math.max(1, Math.round(box ? fraction(box.height) * image.naturalHeight : image.naturalHeight));
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return null;
  context.fillStyle = '#fff';
  context.fillRect(0, 0, width, height);
  context.drawImage(image, x, y, width, height, 0, 0, width, height);
  return toFile(canvas, name, 'image/jpeg');
}

/**
 * The part of a document Ayla pointed at. Without a box only a photo counts as a whole: a whole PDF page is a document,
 * never a logo or a cover (iOS VaultAddEvidenceModel.part).
 */
async function part(
  files: File[],
  reading: VaultEvidenceReading,
  index: number | null,
  box: VaultEvidenceBox | null,
  name: string,
) {
  if (index === null || !files[index]) return null;
  const image = reading.documents[index]?.image;
  if (!image || (!box && !files[index].type.startsWith('image/'))) return null;
  return cut(image, box, name);
}

export interface AylaPictures {
  logo: File | null;
  logoSource: string | null;
  cover: File | null;
}

/**
 * The logo and the cover Ayla chose. A photo that is only the logo is the sharpest; then the logo from the
 * organisation's website; then the logo cut from the page where she saw it.
 */
export async function aylaPictures(
  proposal: VaultEvidenceProposal,
  files: File[],
  reading: VaultEvidenceReading,
  wantsLogo: boolean,
  wantsCover: boolean,
): Promise<AylaPictures> {
  const result: AylaPictures = { logo: null, logoSource: null, cover: null };
  if (wantsLogo) {
    const whole = proposal.logoBox ? null : await part(files, reading, proposal.logoDocument, null, 'logo.jpg');
    if (whole) result.logo = whole;
    else if (proposal.logo) {
      const type = proposal.logo.mimeType || 'image/png';
      const bytes = Uint8Array.from(atob(proposal.logo.data), (character) => character.charCodeAt(0));
      result.logo = new File([bytes], `logo.${type.split('/')[1]?.split('+')[0] ?? 'png'}`, { type });
      result.logoSource = proposal.logo.source;
    } else if (proposal.logoBox) result.logo = await part(files, reading, proposal.logoDocument, proposal.logoBox, 'logo.jpg');
  }
  if (wantsCover) result.cover = await part(files, reading, proposal.coverDocument, proposal.coverBox, 'omslag.jpg');
  return result;
}

const CATEGORIES: VaultItemCategory[] = [
  'diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback', 'reflections', 'other',
];

/** What Ayla knows from the chat as a proposal like the one from reading files, without files of its own. */
export function proposalFromChat(item: AylaVaultItemProposal): VaultEvidenceProposal {
  return {
    category: (CATEGORIES as string[]).includes(item.category) ? (item.category as VaultItemCategory) : 'other',
    title: item.title ?? '',
    organisationName: item.organisationName ?? null,
    organisationLocation: item.organisationLocation ?? null,
    startDate: item.startDate ?? null,
    endDate: item.endDate ?? null,
    issuedOn: item.issuedOn ?? null,
    isCurrent: item.isCurrent ?? false,
    description: item.description ?? null,
    skills: (item.skills ?? []).map((name) => ({ name, reason: 'Uit je gesprek met Ayla' })),
    folder: null,
    documents: [],
    coverDocument: null,
    coverBox: null,
    logoDocument: null,
    logoBox: null,
    website: null,
    sources: {},
    logo: null,
  };
}

/**
 * What the files say, completed with what the user told in the chat (iOS VaultEvidenceProposal.merged). The chat wins on
 * the facts the user states (title, organisation, period); the files win on the description; the skills come from both;
 * logo, cover, folder and sources are only in the files.
 */
export function mergedWithChat(files: VaultEvidenceProposal, item: AylaVaultItemProposal): VaultEvidenceProposal {
  const chat = proposalFromChat(item);
  const result = { ...files };
  if ((CATEGORIES as string[]).includes(item.category)) result.category = chat.category;
  if (chat.title) result.title = chat.title;
  if (chat.organisationName) {
    result.organisationName = chat.organisationName;
    result.organisationLocation = chat.organisationLocation ?? result.organisationLocation;
  }
  if (chat.startDate || chat.issuedOn) {
    result.startDate = chat.startDate;
    result.endDate = chat.endDate;
    result.issuedOn = chat.issuedOn;
    result.isCurrent = chat.isCurrent;
  }
  if (!result.description && chat.description) result.description = chat.description;
  const known = new Set(result.skills.map((skill) => skill.name.toLowerCase()));
  result.skills = [...result.skills, ...chat.skills.filter((skill) => !known.has(skill.name.toLowerCase()))];
  return result;
}

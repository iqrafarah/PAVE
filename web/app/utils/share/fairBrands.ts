// The look of each employer of the fair demo, the same as on its poster: colours, logo and line. An employer without
// one keeps PAVE's plain header.

export interface FairBrand {
  logo: string;
  background: string;
  accent: string;
  ink: string;
  kicker?: string;
  headline: string;
  motif: 'chevron' | 'sun' | 'rings' | 'band' | 'zigzag';
  mono: boolean;
  plateRadius: string;
  uppercase: boolean;
}

const brands: Record<string, FairBrand> = {
  ogd: {
    logo: '/images/fair/ogd.png', background: '#034EA1', accent: '#37CFB1', ink: '#FFFFFF',
    kicker: '> werken bij ogd', headline: 'Start je\nict-carrière_', motif: 'chevron', mono: true, plateRadius: '10px', uppercase: false,
  },
  'sioux-technologies': {
    logo: '/images/fair/sioux.svg', background: '#0D0D0D', accent: '#E41B23', ink: '#FFFFFF',
    kicker: '// engineering', headline: 'Engineers\ngezocht', motif: 'sun', mono: true, plateRadius: '4px', uppercase: true,
  },
  'catharina-ziekenhuis': {
    logo: '/images/fair/catharina.svg', background: '#66456C', accent: '#24BBE5', ink: '#FFFFFF',
    headline: 'Werken in\nde zorg?', motif: 'rings', mono: false, plateRadius: '30px', uppercase: false,
  },
  jumbo: {
    logo: '/images/fair/jumbo-touch.png', background: '#EEB717', accent: '#E30613', ink: '#000000',
    headline: 'Kom bij Jumbo', motif: 'band', mono: false, plateRadius: '12px', uppercase: true,
  },
  'gemeente-eindhoven': {
    logo: '/images/fair/eindhoven.svg', background: '#EF4433', accent: '#FFFFFF', ink: '#FFFFFF',
    headline: 'Werk aan\nje eigen stad', motif: 'zigzag', mono: false, plateRadius: '8px', uppercase: false,
  },
};

export function fairBrand(slug: string): FairBrand | undefined {
  return brands[slug];
}

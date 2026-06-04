import { BadRequestException } from '@nestjs/common';
import {
  sanitizeOverlaySvg,
  sanitizeTemplateDefaults,
} from './overlay-sanitize';

describe('overlay-sanitize', () => {
  it('accepts minimal svg', () => {
    const out = sanitizeOverlaySvg(
      '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
    );
    expect(out).toContain('<svg');
  });

  it('rejects script tags', () => {
    expect(() =>
      sanitizeOverlaySvg('<svg><script>alert(1)</script></svg>'),
    ).toThrow(BadRequestException);
  });

  it('sanitizes template defaults with fabric and svg', () => {
    const d = sanitizeTemplateDefaults({
      fabric_scene: { version: '6.0.0', objects: [] },
      overlay_svg: '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
      editor_text_en: 'note',
    });
    expect(d?.fabric_scene).toBeDefined();
    expect(d?.overlay_svg).toContain('<svg');
    expect(d?.editor_text_en).toBe('note');
  });
});

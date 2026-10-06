import { CheckboxInput, type FeatureChoiced, type FeatureToggle } from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const disable_lobby_transparency: FeatureToggle = {
  name: 'Disable Lobby-menu Transparency',
  category: 'UI',
  description: 'Prevent admins from making the lobby screen transparent.',
  component: CheckboxInput,
};

export const lobby_language: FeatureChoiced = {
  name: 'Lobby Language',
  category: 'UI',
  description:
    'Language used by the HTML lobby menu (English or Russian). ' +
    'Can also be switched directly from the lobby settings button.',
  component: FeatureDropdownInput,
};

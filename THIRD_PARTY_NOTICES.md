# Third-party notices and asset attribution

This file records the provenance and license information available in the
project checkout. It does not replace the complete license texts or legal terms
published by the respective authors.

## Meditation Timer

This source snapshot contains a modified version of Meditation Timer.

- Upstream repository: https://github.com/vpnry/ekatimer
- Baseline tag: `v1.0.20`
- Baseline commit: `0acc5e58a93c7b8082d4dab5e440468b4a599197`
- Upstream license: GNU General Public License version 3

The upstream copyright and attribution notices must be preserved.

## Meditation Assistant

Meditation Timer was inspired by Meditation Assistant, authored by Trevor Slocum, and
reimplemented concepts from that GPLv3 project.

- Source: https://codeberg.org/tslocum/meditationassistant

## Audio assets

Third-party audio assets are not relicensed merely because they are distributed
beside GPL-covered source. They remain subject to their listed terms.

### Free Dhamma Gift attribution

- `Sadhu.wav`
- Author: Ven. Pa-Auk Tawya Sayadaw
- Project record: adapted from Pa-Auk Forest Monastery chanting audio and
  described in the application as a Dhamma Gift

The checkout does not contain a separate written license for this recording.
The publisher should retain the attribution and confirm redistribution
permission or replace the asset before a production public release.

### CC0 1.0 Universal / public-domain dedication

License/deed: https://creativecommons.org/publicdomain/zero/1.0/

The project records the following files as sourced from Joseph Sardin at
BigSoundBank.com:

- `Bell.wav`
- `GardenBird.wav`
- `Bowl.wav`
- `BowlStrong.wav`
- `Watch.wav`

### Creative Commons Attribution 4.0

License: https://creativecommons.org/licenses/by/4.0/

| File | Author | Source |
|---|---|---|
| `ThreeBowl.wav` | naturenotesuk | https://freesound.org/s/667491/ |
| `Gong.wav` | reinsamba | https://freesound.org/s/46062/ |

Retain author, source, and CC BY 4.0 attribution when redistributing these
recordings.

## Quotes, translations, and project artwork

`assets/quotes/quotes.json`, translated UI resources, Quality illustrations,
and the modified launcher artwork are distributed as application assets. A
separate provenance/license file for every translated quotation and newly added
artwork was not present in the checkout. The publisher should confirm
authorship or permission for those additions before representing them as
relicensable under GPLv3.

Unused draft Quality PNGs are deliberately omitted from the source archive;
the released UI renders Quality with Flutter star icons.

## Flutter and Dart dependencies

Flutter, Dart, Android build tools, and packages resolved from pub.dev are
separate third-party components under their own licenses. `pubspec.yaml` lists
the direct dependencies; `pubspec.lock` records exact resolved versions,
download sources, and integrity hashes. Their source and license files are
obtained by the standard Flutter/Dart dependency tooling and are not copied
into this source archive.

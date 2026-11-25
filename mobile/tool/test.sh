#!/usr/bin/env bash
# Toute la suite `flutter test`, regroupée en paquets (tool/test_bundles.dart) : les fichiers
# d'un paquet partagent une compilation et un isolate. Un fichier seul se lance toujours avec
# `flutter test test/…_test.dart`.
#
#   bash tool/test.sh                    # toute la suite
#   TEST_BUNDLES=8 bash tool/test.sh     # nombre de paquets (défaut : nombre de cœurs)
#   bash tool/test.sh --name 'RL4'       # les options passent à `flutter test`
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

dart tool/test_bundles.dart ${TEST_BUNDLES:-}
exec flutter test .dart_tool/test_bundles "$@"

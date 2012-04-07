#!/bin/sh
# Written by Douglas Goldstein <cardoe@gentoo.org>
# This code is hereby placed into the public domain
#
# $Id: use_desc_gen.sh,v 1.6 2008/08/23 21:28:28 robbat2 Exp $

overlaydir=${OVERLAY:-/g2pfx/overlay}

${overlaydir}/scripts/metadata_gen.sh
rm -rvf ${overlaydir}/portage_diffs/latest
${overlaydir}/scripts/gendiffs

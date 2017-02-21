#!/usr/bin/env python
import argparse
import copy
import logging
import re
import sys

from BCBio import GFF

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(name='blastxml2gff3')

def blastxml2gff3(blastxml):
    from Bio.Blast import NCBIXML
    from Bio.Seq import Seq
    from Bio.SeqRecord import SeqRecord
    from Bio.SeqFeature import SeqFeature, FeatureLocation

    blast_records = NCBIXML.parse(blastxml)
    records = {}
    for record in blast_records:
        # http://www.sequenceontology.org/browser/release_2.4/term/SO:0000343
        match_type = 'match'

        for hit in record.alignments:
            if hit.accession in records:
                rec = record[hit.accession]
            else:
                rec = SeqRecord(Seq("ACTG"), id=hit.accession)

            for hsp in hit.hsps:
                strand  = hsp.frame[1]
                qualifiers = {
                    "source": "blast",
                    "score": hsp.expect,
                    "accession": hit.accession,
                    "hit_name": record.query
                }
                desc = hit.title.split(' >')[0]
                desc = desc[desc.index(' '):]
                if desc != ' No definition line':
                    qualifiers['description'] = desc

                parent_match_start = hsp.sbjct_start
                parent_match_end = hsp.sbjct_end

                # The ``match`` feature will hold one or more ``match_part``s
                top_feature = SeqFeature(
                    FeatureLocation(parent_match_start, parent_match_end),
                    type=match_type, strand=strand,
                    qualifiers=qualifiers
                )
                top_feature.sub_features = []

                part_qualifiers = {
                    "source": "blast",
                    'ID': hit.hit_id
                }

                match_part_start = hsp.sbjct_start
                match_part_end = hsp.sbjct_end

                top_feature.sub_features.append(
                    SeqFeature(
                        FeatureLocation(match_part_start, match_part_end),
                        type="match_part", strand=strand,
                        qualifiers=copy.deepcopy(part_qualifiers))
                )

                rec.features.append(top_feature)
            rec.annotations = {}
            records[hit.hit_id] = rec
    return records.values()




if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert Blast XML to GFF3', epilog='')
    parser.add_argument('blastxml', type=open, help='Blast XML Output')
    args = parser.parse_args()

    result = blastxml2gff3(**vars(args))
    GFF.write(result, sys.stdout)

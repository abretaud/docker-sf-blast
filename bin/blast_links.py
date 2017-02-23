#!/usr/bin/env python

# A script to add links to blast results (HTML file)

from __future__ import print_function

import argparse
import os, sys, shutil
import re, yaml, yamlordereddictloader


class LinkInjector():

    def __init__(self):

        self.db_regex = "^Database: (.+)$"
        self.summary_regex = "^Sequences producing significant alignments:"

        self.links = [] # Contains the cleanup configuration for link injection

    def main(self):

        self.parse_args()

        self.load_config()

        self.parse_html()

    def parse_args(self):

        parser = argparse.ArgumentParser()
        parser.add_argument( '--config', help='Path to a config file (default=links_config.yml in script directory' )
        parser.add_argument('infile', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
        parser.add_argument('outfile', nargs='?', type=argparse.FileType('w'), default=sys.stdout)
        self.args = parser.parse_args()

    def load_config(self):

        """
        Syntax exampe (YAML) is following.
        The regex are tested in the same order as written in yaml and it stops searching after the first match.
        You don't need to add the "lcl|" prefix to seq id regex, a generic regex is added by this script (if you don't want it, start your regex with ^)

        genome:    # you can give any name, it is not used by the script
            db:                     '\w+genome\w+'    # optional regex to restrict to a specific blast database
            '(scaffold\w+)':         '<a href="http://tripal/{id}"></a> <a href="http://jbrowse?loc={id}">JBrowse</a>'    # key is a regex to match seq ids, value is a full html block, or simply an http url
            '(superscaffold\w+)':    'http://tripal/{id}'
            '(hyperscaffold\w+)':    'http://jbrowse?loc={id}{jbrowse_track}' # {jbrowse_track} will be replaced by proper argument to add a custom jbrowse track based on the gff_url
            '(xxscaffold\w+)':    'http://apollo?loc={id}{apollo_track}' # {apollo_track} will be replaced by proper argument to add a custom jbrowse track based on the gff_url
            '(yyscaffold\w+)':    'http://google/{gff_url}' # {gff_url} will be replaced by the url of the gff output
        protein:
            db:                     '.+protein.+'
            '*':                    'http://tripal/{id}'
        other:
            '*':                    'http://google/{id}'
        """
        conf_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "links_config.yml")
        if self.args.config:
            conf_file = self.args.config

        y = yaml.load(open(conf_file), Loader=yamlordereddictloader.Loader)

        if y:
            for conf_cat in y.values():

                if 'db' in conf_cat:
                    db = conf_cat['db']
                else:
                    db = '.+'

                for regex in conf_cat:
                    if regex != 'db': # skip db line
                        url = conf_cat[regex]
                        if regex == '*': # Add a default regex
                            regex = '([\w.-]+)'
                        if not regex.startswith('^'): # Add the seq id prefix rule (e.g. 'lcl|' or '>lcl|', ...)
                            regex = '^(\s*>?(?:[\w.-]+\|)?)?' + regex
                        if url.startswith('http'): # Convert simple url to html link
                            url = '<a href="%s">{id}</a>' % url
                        self.links.append((db, regex,  url))

    def parse_html(self):

        current_db = None # Name of the blast database that was used
        reached_summary = False # Did we reached the beginning of the summary?
        started_summary = False # Did we start to inject links in the summary?
        finished_summary = False # Did we pass the end of the summary?

        for line in self.args.infile:

            line = line.rstrip('\n')

            # Find the name of the blast db that was used (at the beginning of the file)
            if not current_db:
                search = re.search(self.db_regex, line)
                if search:
                    current_db = search.group(1)

                print(line, file=self.args.outfile)
                continue # We have not yet (or just) reached the database line, skip to next line

            # Find the result summary
            if not reached_summary:
                if re.match(self.summary_regex, line):
                    reached_summary = True

                print(line, file=self.args.outfile)
                continue # We have not yet (or just) reached the database line, skip to next line

            # The summary really starts after a blank line
            if reached_summary and not started_summary:
                started_summary = True
                print(line, file=self.args.outfile)
                continue

            # Treating the summary
            if started_summary and not finished_summary:
                # Empty line means we reached the end of the summary
                if not line:
                    finished_summary = True
                    print(line, file=self.args.outfile)
                    continue

                line = self.inject_link(current_db, line)
                print(line, file=self.args.outfile)
                continue

            # Passed the summary, reached alignments
            if line.startswith('>'):
                line = self.inject_link(current_db, line)

            # Sometimes the html contains an aditional tag for the first alignment of a query
            if line.startswith('<script src="blastResult.js"></script>'):
                script_tag_len = len('<script src="blastResult.js"></script>')
                print(line[:script_tag_len] + '\n', file=self.args.outfile) # split the line to ease replacement
                line = self.inject_link(current_db, line[script_tag_len:])

            # Detect when we switch to another query
            if line.startswith('Query='):
                reached_summary = False
                started_summary = False
                finished_summary = False

            if line.startswith('</BODY>'):
                js_replace = """<script type=\"text/javascript\">
window.onload = function(){
    var as = document.getElementsByTagName("a");
    var gff_url = '';
    for(var i = 0; i < as.length; i++){
        if (as[i].innerHTML == 'GFF3 blast output')
             gff_url = as[i].href;
    }
    for(var i = 0; i < as.length; i++){
       as[i].href = as[i].href.replace('{gff_url}', gff_url);
    }
}
</script>"""
                print(js_replace, file=self.args.outfile)

            print(line, file=self.args.outfile)

    def inject_link(self, db, line):

        # Url encoded json
        jbrowse_track = "&addStores=%7B%22url%22%3A%7B%22type%22%3A%22JBrowse%2FStore%2FSeqFeature%2FGFF3%22%2C%22urlTemplate%22%3A%22{gff_url}%22%7D%7D&addTracks=%5B%7B%22label%22%3A%22Blast results%22%2C%22type%22%3A%22JBrowse%2FView%2FTrack%2FCanvasFeatures%22%2C%22store%22%3A%22url%22%7D%5D&tracks=Blast%20results"
        # Double url encoded json (same as for jbrowse, but for x reason it needs to be encoded 2 times...)
        apollo_track = "&addStores=%257B%2522url%2522%253A%257B%2522type%2522%253A%2522JBrowse%252FStore%252FSeqFeature%252FGFF3%2522%252C%2522urlTemplate%2522%253A%2522{gff_url}%2522%257D%257D&addTracks=%255B%257B%2522label%2522%253A%2522Blast%20results%2522%252C%2522type%2522%253A%2522JBrowse%252FView%252FTrack%252FCanvasFeatures%2522%252C%2522store%2522%253A%2522url%2522%257D%255D%22&tracks=Blast%2520results"

        for rule in self.links:
            if re.match(rule[0], db):
                id_search = re.search(rule[1], line)
                if id_search:
                    seq_id = id_search.group(2)
                    clean_link = rule[2].replace('{db}', db)
                    clean_link = clean_link.replace('{id}', seq_id)
                    clean_link = clean_link.replace('{jbrowse_track}', jbrowse_track)
                    clean_link = clean_link.replace('{apollo_track}', apollo_track)
                    return re.sub(rule[1], '\\1'+clean_link, line)

        return line


if __name__ == '__main__':
    li = LinkInjector()

    li.main()

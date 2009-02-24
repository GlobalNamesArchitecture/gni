#!/usr/bin/env python
import os
import sys
from urllib import urlopen
import libxml2
import MySQLdb
import yaml
import cjson
import sha
import time
from optparse import OptionParser
import re
#import cProfile
    
import pprint
pp = pprint.PrettyPrinter(indent=2)
packet_size = 5000
commit_size = 50000
del_chars=re.compile('[.;,]')
space_char = re.compile('([-\(\)\[\]\{\}:&?\*])')
x_char = re.compile('\s+[xX]\s+')
mult_spaces = re.compile('\s{2,}')

def run_imports(source,source_id,environment): 
    
    i = Importer(source, source_id, environment)
    #cProfile.run('i.parse()')
    i.db_clean_imports()
    for ii in i.parse():
        yield ii
    print "data entered for processing"
    
    print "Processing"
    i.process()
    
    print "Migrating"
    i.migrate_data()
    
    print "Finding overlaps"
    i.find_overlaps()
    
    print "Committing"
    i.db_commit()

def normalize_name_string(name_string):
    name_string = name_string.lower()
    name_string = del_chars.sub(' ', name_string)
    name_string = space_char.sub(r' \1 ', name_string)
    name_string = mult_spaces.sub(' ', name_string)
    return name_string.strip()

class DbImporter: #{{{1

    def escape_data(self,data): #{{{2
        for key in data.keys():
            if data[key]:
                if type(data[key]) == type(''):
                    data[key] = "'" + MySQLdb.escape_string(str(data[key])) + "'"
            else:
                data[key] = 'null'
        for key in ('source','identifier','GlobalUniqueIdentifier', 'Kingdom', 'Rank'):
            if not data.has_key(key):
                data[key] = 'null'
        if data['Simple'] == "'Orthoschema tenuicorne Bates, 1870'":
            pp.pprint(data)
        return data

    def __init__(self, environment): #{{{2
        self.environment = environment
        self.conn = self._connect()
        self.cursor = self.conn.cursor()

    def _connect(self):
        db_data = os.popen('erb ' + sys.path[0] + '/../../config/database.yml').read()
        db_conf =  yaml.load(db_data)[self.environment]
        if not db_conf.has_key('socket'):
            db_conf['socket'] = "/tmp/mysql.sock"

        conn = MySQLdb.connect (
            host = db_conf['host'],
            user = db_conf['username'],
            passwd = db_conf['password'],
            unix_socket = db_conf['socket'],
            db = db_conf['database'])

        return conn

class Importer: #{{{1

    def __init__(self, source, data_source_id, environment): #{{{2
        self.db = DbImporter(environment)
        self.imported_data = []
        self.counter = 0
        self.time = time.time()
        self.kingdoms = self._prepare_kingdoms()

        self.reader = libxml2.newTextReaderFilename(source)
        self.data_source_id = data_source_id

        self._current_tag = None
        self._record = self._reset_record()

    def parse(self): #{{{2
        ret = self.reader.Read()
        while ret == 1:
            for i in self._process_node():
                yield i
            ret = self.reader.Read()
        if ret != 0:
            raise RuntimeError("%s : failed to parse" % (filename))
        #add the rest of the 'tail' data 
        self._insert()

    def process(self): #{{{2
        pass

    def migrate_data(self): #{{{2
        c = self.db.cursor
        c.execute('delete ni, nir from name_indices ni join name_index_records nir on (ni.id=nir.name_index_id) where ni.data_source_id = %s' % self.data_source_id)
        
        print "second query";
        c.execute('insert IGNORE into name_indices (name_string_id, data_source_id, created_at, updated_at) (select name_string_id, data_source_id, now(), now() from import_name_index_records)')
        
        print "third query";
        c.execute('insert IGNORE into name_index_records (name_index_id, kingdom_id, rank, local_id, global_id, url, created_at, updated_at) (select ni.id, inir.kingdom_id, inir.rank, inir.local_id, inir.global_id, inir.url, now(), now() from import_name_index_records inir join name_indices ni on (inir.name_string_id = ni.name_string_id) where ni.data_source_id = %s )' % self.data_source_id)
    
    def find_overlaps(self):  #{{{2
        c = self.db.cursor
        c.execute("delete from data_source_overlaps where data_source_id_1 = %s or data_source_id_2 = %s", (self.data_source_id, self.data_source_id))
        c.execute("select id from data_sources where id != %s", self.data_source_id)
        data_sources = map(lambda x: x[0], c.fetchall())
        data_sources.sort
        for i in data_sources:
            c.execute("SELECT COUNT(distinct ni_from.name_string_id) as overlap FROM name_indices ni_from JOIN name_indices ni_to ON (ni_from.name_string_id = ni_to.name_string_id) WHERE ni_from.data_source_id = %s AND ni_to.data_source_id = %s", (self.data_source_id, i))
            overlap = c.fetchone()[0]
            c.execute("insert into data_source_overlaps (data_source_id_1, data_source_id_2, strict_overlap, created_at, updated_at) values (%s, %s, %s, now(), now())", (self.data_source_id, i, overlap))
            c.execute("insert into data_source_overlaps (data_source_id_1, data_source_id_2, strict_overlap, created_at, updated_at) values (%s, %s, %s, now(), now())", (i, self.data_source_id, overlap))
    
    def db_commit(self): #{{{2
        self.db.conn.commit()
    
    def db_clean_imports(self): #{{{2
        c = self.db.cursor
        c.execute("truncate import_name_index_records")
        self.db_commit()
        
    #private functions #{{{2
    def _prepare_kingdoms(self):
        c = self.db.cursor
        c.execute("select n.id, n.name from kingdoms k join name_strings n on n.id = k.name_string_id")
        res = c.fetchall()
        kingdoms = {}
        for i in res:
            kingdoms[i[1].lower()] = i[0]
        return kingdoms

    def _process_node(self): #{{{2
        if self.reader.NodeType() == 1: #start of a tag
            try:
                tag = self.reader.Name().split(':')[-1]
                ["Simple", "Kingdom", "Rank", "source", "identifier", "GlobalUniqueIdentifier"].index(tag)
                self._current_tag = tag
            except ValueError, e:
                self._current_tag = None
        elif self.reader.NodeType() == 15: #end of a tag
            if self.reader.Name() == "TaxonName":
                self.counter += 1
                if self.counter % 10000 == 0:
                    new_time = time.time()
                    yield "Processing %sth record. Average Speed: %2d records per second." % (self.counter,self.counter/(new_time - self.time))
                self._append_imported_data()
                self._record = self._reset_record()
                if len(self.imported_data) >= commit_size:
                    self._insert()
        elif self.reader.NodeType() == 3 and self._current_tag: #text node
            self._record[self._current_tag] = self.reader.Value().strip()
            self._current_tag = None

    def _append_imported_data(self): #{{{2
        try:
            self._record['Kingdom'] = self.kingdoms[self._record['Kingdom'].lower()]
        except KeyError:
            self._record['Kingdom'] = None
        self.imported_data.append(self._record.copy())
            
    def _reset_record(self): #{{{2
        return {'data_source_id': self.data_source_id}
        
    def _name_lookup(self, name_string): #{{{2
        normalized_name_string = normalize_name_string(name_string)
        self.db.cursor.execute("select id from name_strings where normalized_name = %s", normalized_name_string)
        name_string_id = self.db.cursor.fetchone()
        if not name_string_id:
            self.db.cursor.execute("insert into name_strings (name, normalized_name, created_at, updated_at) values (%s, %s, now(), now())", (name_string, normalized_name_string))
            self.db.cursor.execute("select last_insert_id()")
            name_string_id = self.db.cursor.fetchone()
        return (name_string_id[0])

    def _insert(self):
        c = self.db.cursor
        records = []
        insert_query = "insert into import_name_index_records (data_source_id, kingdom_id, name_string, name_string_id, rank, local_id, global_id, url, created_at, updated_at) values %s"
        for i in self.imported_data:
            i['name_string_id'] = self._name_lookup(i['Simple'])
            data = self.db.escape_data(i)
            try:
                records.append("(%(data_source_id)s, %(Kingdom)s, %(Simple)s, %(name_string_id)s, %(Rank)s, %(identifier)s, %(GlobalUniqueIdentifier)s, %(source)s, now(), now())" % data)
            except Exception, e:
                print data.keys()
                print data.values()
                raise Exception
            if len(records) >= packet_size:
                c.execute(insert_query % ",".join(records)) 
                #print(':mysql: records ' + str(count))
                records=[]
        if records:
            c.execute(insert_query % ",".join(records)) 
        #print(':mysql: name_index_records inserts are done')
        self.db_commit()
        self.imported_data = []
    
    
    # def _db_insert(self): #{{{2
    #     c = self.db.cursor
    #     c.execute('select max(id) from name_indices')
    #     res = c.fetchall()
    #     if res[0][0]:
    #         last_id = res[0][0]
    #     else:
    #         last_id = 0 
    #     insert_query = "insert into name_indices (data_source_id, name_string_id, records_hash, created_at, updated_at) values %s"
    #     if self.inserted:
    #         inserts = []
    #         count = 0
    #         for i in self.inserted:
    #             count += 1
    #             #data = self.db.escape_data(self.imported_data[i])
    #             data = {}
    #             data['name_string_id'] = i
    #             data['data_source_id'] = self.data_source_id
    #             data['records_hash'] = self.imported_data[i]['hash'] 
    #             inserts.append("(%(data_source_id)s, %(name_string_id)s, '%(records_hash)s' , now(), now())" % data)
    #             if len(inserts) >= packet_size:
    #               c.execute(insert_query % ",".join(map(lambda x: str(x),inserts)))
    #               #print(':mysql: inserted ' + str(count))
    #               inserts=[]
    #         if inserts:
    #             c.execute(insert_query % ",".join(map(lambda x: str(x),inserts)))
    #         
    #         #print("select id, name_string_id from name_indices where data_source_id = %s and id > %s" % (self.data_source_id, last_id) )
    #         c.execute("select id, name_string_id from name_indices where data_source_id = %s and id > %s" % (self.data_source_id, last_id) )
    #         #print(':mysql: name_indices inserts are done')
    #         res = c.fetchall()
    #         records = []
    #         count = 0
    #         insert_query = "insert into name_index_records (name_index_id, record_hash, url, local_id, global_id, kingdom_id, rank, created_at, updated_at) values %s"
    #         for i in res:
    #             count += 1
    #             name_index_id = i[0]
    #             name_string_id = i[1]
    #             for d in self.imported_data[name_string_id]['data']:
    #                 data = self.db.escape_data(d)
    #                 data['name_index_id'] = name_index_id
    #                 records.append("(%(name_index_id)s, %(hash)s, %(source)s, %(identifier)s, %(GlobalUniqueIdentifier)s, %(Kingdom)s, %(Rank)s, now(), now())" % data)
    #                 if len(records) >= packet_size:
    #                     c.execute(insert_query % ",".join(records)) 
    #                     #print(':mysql: records ' + str(count))
    #                     records=[]
    #         if records:
    #             c.execute(insert_query % ",".join(records)) 
    #         #print(':mysql: name_index_records inserts are done')
    # def db_update(self): #{{{2
    #     c = self.db.cursor
    #     if self.changed:
    #         c.execute("select id, name_string_id from name_indices where  name_string_id in (%s)" % ",".join(map(lambda x: str(x), self.changed)))
    #         res = c.fetchall()
    #         updates = map(lambda x: str(x[0]), res)
    #         c.execute("delete from name_index_records where name_index_id in (%s)" % ",".join(updates))
    #         for i in res:
    #             name_string_id = i[1]
    #             name_index_id = i[0]
    #             hash = self.imported_data[name_string_id]['hash']
    #             c.execute("update name_indices set records_hash = %s where data_source_id = %s and name_string_id = %s", (hash, self.data_source_id, name_string_id))
    #             records = []
    #             for d in self.imported_data[i[1]]['data']:
    #                 data = self.db.escape_data(d)
    #                 data['name_index_id'] = name_index_id
    #                 #pp.pprint(data)
    #                 records.append("(%(name_index_id)s, %(hash)s, %(source)s, %(identifier)s, %(GlobalUniqueIdentifier)s, %(Kingdom)s, %(Rank)s, now(), now())" % data)
    #             c.execute("insert into name_index_records (name_index_id, record_hash, url, local_id, global_id, kingdom_id, rank, created_at, updated_at) values %s" % ",".join(records)) 
    # 
    # 
    # def _find_overlaps(self):  #{{{2
    #     c = self.db.cursor
    #     c.execute("delete from data_source_overlaps where data_source_id_1 = %s or data_source_id_2 = %s", (self.data_source_id, self.data_source_id))
    #     c.execute("select id from data_sources where id != %s", self.data_source_id)
    #     data_sources = map(lambda x: x[0], c.fetchall())
    #     data_sources.sort
    #     overlap_data = []
    #     for i in data_sources:
    #         c.execute("select name_string_id from name_indices where data_source_id = %s", i)
    #         other_data_source_name_ids = set(map(lambda x: x[0], c.fetchall()))
    #         intersect_size = len(self._new_ids.intersection(other_data_source_name_ids))
    #         overlap_data.append("(%s, %s, %s, now(), now())" % (self.data_source_id, i, intersect_size))
    #     c.execute("insert into data_source_overlaps (data_source_id_1, data_source_id_2, strict_overlap, created_at, updated_at) values %s" % ",".join(overlap_data))
    # 
    # def _db_store_statistics(self): #{{{2
    #   #c.execute("delete from import_details where created_at 
    #   self._import_stats(self.deleted, 'delete')
    #   self._import_stats(self.inserted, 'insert')
    #   self._import_stats(self.changed, 'update')
    #   return "Deleted: %s, Inserted: %s, Changed: %s" % (len(self.deleted), len(self.inserted), len(self.changed))
    # 
    # 
    # def _add_hash_to_imports(self):
    #     imp =  self.imported_data
    #     for key in imp.keys():
    #         hashes = [] 
    #         for d in imp[key]['data']:
    #             data_keys = d.keys()
    #             data_keys.sort()
    #             data_array = map(lambda x: d[x], data_keys)
    #             normalized_data = cjson.encode(data_array).replace(' ','')
    #             #print normalized_data
    #             normalized_data = sha.new(normalized_data).hexdigest()
    #             #print normalized_data
    #             d['hash'] = normalized_data
    #             hashes.append(normalized_data)
    #         hashes.sort()
    #         record_hashes = sha.new(''.join(hashes)).hexdigest()
    #         #:print record_hashes
    #         imp[key]['hash']= record_hashes
    # 
    # def _import_stats(self, data, name): #{{{2
    #     c = self.db.cursor
    #     if len(data):
    #         c.execute("insert into data_source_imports (data_source_id, name, created_at, updated_at) values (%s, %s, now(), now())", (self.data_source_id, name))
    #         c.execute("select last_insert_id()")
    #         imports_id = c.fetchone()[0]
    #         inserts = []
    #         for i in data:
    #             inserts.append("(%s, %s, now(), now())" % (imports_id, i))
    #         c.execute("insert into data_source_import_details (data_source_import_id, name_string_id, created_at, updated_at) values %s" % ",".join(inserts))

if __name__ == '__main__': #script part {{{1
    opts = OptionParser()
    opts.add_option("-e", "--environment", dest="environment", default="development",
        help="Specifies the environment of the system (development|test|producton).")
    
    opts.add_option("-s", "--source", dest="source",
        help="Specifies url/filename which contains data for harvesting.")
    
    opts.add_option("-i", "--source-id", dest="source_id",
        help="Identifier of the data_source in GNA database.")
    
    (options, args) = opts.parse_args()
    
    if not (options.source and options.source_id and type(int(options.source_id)) == type(1)):
        raise Exception("source file/url and source id are required")
    
    for status in run_imports(options.source, options.source_id, options.environment):
        print status
    

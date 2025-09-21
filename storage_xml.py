import os, threading
from xml.etree import ElementTree as ET


class XmlStorage:
def __init__(self, path:str):
self.path = path
self.lock = threading.Lock()
os.makedirs(os.path.dirname(path), exist_ok=True)
if not os.path.exists(path):
root = ET.Element('apec-bookings')
ET.ElementTree(root).write(path, encoding='utf-8', xml_declaration=True)


def _read(self):
tree = ET.parse(self.path)
return tree, tree.getroot()


def list_for_date(self, date:str):
with self.lock:
_, root = self._read()
out=[]
for b in root.findall('booking'):
if b.get('date')==date:
out.append({
'id': int(b.get('id')),
'company': b.get('company'),
'email': b.get('email'),
'tier': b.get('tier'),
'room_code': b.get('room_code'),
'date': b.get('date'),
'start_hour': int(b.get('start')),
'end_hour': int(b.get('end')),
'blocks': int(b.get('blocks')),
})
return out


def create(self, payload:dict):
with self.lock:
tree, root = self._read()
next_id = 1 + max([int(b.get('id')) for b in root.findall('booking')] or [0])
el = ET.SubElement(root, 'booking')
el.set('id', str(next_id))
el.set('company', payload['company'])
el.set('email', payload['email'])
el.set('tier', payload['tier'])
el.set('room_code', payload['room_code'])
el.set('date', payload['date'])
el.set('start', str(payload['start_hour']))
el.set('end', str(payload['end_hour']))
el.set('blocks', str(payload['blocks']))
tree.write(self.path, encoding='utf-8', xml_declaration=True)
return next_id

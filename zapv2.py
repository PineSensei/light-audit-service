# zapv2.py — ZAP API client
# pulled from https://github.com/zaproxy/zaproxy/blob/main/automation/src/main/python/zapv2.py

import urllib.parse, urllib.request, json

class ZAPv2(object):
    def __init__(self, apikey='', proxies=None):
        self.base = 'http://127.0.0.1:8090'
        if proxies:
            # if you need proxies, you can configure urllib
            handler = urllib.request.ProxyHandler(proxies)
            opener = urllib.request.build_opener(handler)
            urllib.request.install_opener(opener)
        self.apikey = apikey

    def _request(self, component, action, **kwargs):
        url = f"{self.base}/{component}/{action}/?apikey={self.apikey}"
        if kwargs:
            url += '&' + urllib.parse.urlencode(kwargs)
        resp = urllib.request.urlopen(url)
        return json.loads(resp.read().decode('utf-8'))

    # Spider methods
    @property
    def spider(self):
        class Spider:
            def __init__(self, parent): self.p=parent
            def scan(self, url): return self.p._request('JSON/spider', 'scan', url=url)['scan']
            def status(self, scanid): return self.p._request('JSON/spider', 'status', scanid=scanid)['status']
        return Spider(self)

    # Active scan methods
    @property
    def ascan(self):
        class Ascan:
            def __init__(self, parent): self.p=parent
            def scan(self, url): return self.p._request('JSON/ascan', 'scan', url=url)['scan']
            def status(self, scanid): return self.p._request('JSON/ascan', 'status', scanid=scanid)['status']
        return Ascan(self)

    # Core/report methods
    @property
    def core(self):
        class Core:
            def __init__(self, parent): self.p=parent
            def htmlreport(self): return urllib.request.urlopen(f"{self.p.base}/OTHER/core/other/htmlreport/?apikey={self.p.apikey}").read().decode('utf-8')
        return Core(self)

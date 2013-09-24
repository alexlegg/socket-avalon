.PHONY: all
all: server client

%.js: %.coffee
	coffee -c $<

CLIENTSRC = client/client.coffee
CLIENTOBJ = ${CLIENTSRC:.coffee=.js}
CLIENTOUT = js/avalon.js

$(CLIENTOUT): $(CLIENTOBJ)
	cat $^ > $@

.PHONY: client
client: $(CLIENTOUT)

SERVERSRC = server/avalon.coffee
SERVEROBJ = ${SERVERSRC:.coffee=.js}
SERVEROUT = avalon.js

$(SERVEROUT): $(SERVEROBJ)
	cat $^ > $@

.PHONY: server
server: $(SERVEROUT)

clean:
	rm -rf ${CLIENTOBJ} ${SERVEROBJ} ${CLIENTOUT} ${SERVEROUT}


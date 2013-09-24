%.js: %.coffee
	coffee -c $<

CLIENTSRC = client/client.coffee
CLIENTOBJ = ${CLIENTSRC:.coffee=.js}
CLIENTOUT = js/avalon.js

$(CLIENTOUT): $(CLIENTOBJ)
	cat $> $@

.PHONY: client
client: $(CLIENTOUT)

SERVERSRC = server/avalon.coffee
SERVEROBJ = ${SERVERSRC:.coffee=.js}
SERVEROUT = avalaon.js

$(SERVEROUT): $(CLIENTOBJ)
	cat $> $@

.PHONY: server
server: $(SERVEROUT)

clean:
	rm -rf *.js js/*.js client/*.js server/*.js


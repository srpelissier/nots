import vibe.d;

shared static this()
{
	auto router = new URLRouter;

	router.get("/", &listNotes);
	router.get("/create", staticTemplate!"create.dt");
	router.get("/note/create", &createNote);
	router.post("/note/create", &createNote);
	router.get("/logout", &logout);
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.sessionStore = new MemorySessionStore;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

void logout(HTTPServerRequest req, HTTPServerResponse res)
{
	noteStore.removeNotes(req.session.id);
	res.terminateSession();
	res.redirect("/");
}

void listNotes(HTTPServerRequest req, HTTPServerResponse res)
{
	if (!req.session) req.session = res.startSession();
	auto allnotes = noteStore.getNotes(req.session.id);
	render!("listnotes.dt", allnotes)(res);
}

void createNote(HTTPServerRequest req, HTTPServerResponse res)
{
	if (req.method != HTTPMethod.GET && req.method != HTTPMethod.POST) return;

	auto formdata = (req.method == HTTPMethod.GET ? &req.query : &req.form);

	Note note;
	note.topic = formdata.get("form_topic");
	note.content = formdata.get("form_content");

	auto allnotes = noteStore.getNotes(req.session.id);
	allnotes ~= note;

	noteStore.setNotes(req.session.id, allnotes);

	res.redirect("/");
}

struct Note
{
	string topic;
	string content;
}

class NoteStore
{
	Note[][string] store;

	static Note[0] empty;

	Note[] getNotes(string id)
	{
		return (id in store) ? store[id] : empty;
	}

	void setNotes(string id, Note[] notes)
	{
		store[id] = notes;
	}

	void removeNotes(string id)
	{
		store.remove(id);
	}
}

private __gshared NoteStore noteStore;

shared static this()
{
	noteStore = new NoteStore();
}

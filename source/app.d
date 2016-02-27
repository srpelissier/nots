import vibe.d;

shared static this()
{
	auto authinfo = new DigestAuthInfo;
	authinfo.realm = "The Note app";

	auto fileServerSettings= new HTTPFileServerSettings;
	fileServerSettings.serverPathPrefix = "/static";

	auto router = new URLRouter;
	router.get("/", staticTemplate!"index.dt");
	router.get("/login", &login);
	router.get("/static/*", serveStaticFiles("public/", fileServerSettings));
	// use for basic athentication
	//router.any("*", performBasicAuth("The Note app", toDelegate(&checkPassword)));
	// use for digest authentication
	//router.any("*", performDigestAuth(authinfo, toDelegate(&digestPassword)));
	// use for form-based authentication
	router.any("*", &ensureAuth);
	router.get("/listnotes", &listNotes);
	router.get("/create", staticTemplate!"create.dt");
	router.get("/note/create", &createNote);
	router.post("/note/create", &createNote);
	router.get("/logout", &logout);
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.sessionStore = new MemorySessionStore;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	settings.sslContext = createSSLContext(SSLContextKind.server);
	settings.sslContext.useCertificateChainFile("cert.pem");
	settings.sslContext.usePrivateKeyFile("key.pem");
	settings.errorPageHandler = toDelegate(&errorPage);
	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

void login(HTTPServerRequest req, HTTPServerResponse res)
{
	if (req.method != HTTPMethod.GET && req.method != HTTPMethod.POST) return;

	auto formdata = (req.method == HTTPMethod.POST? &req.form : &req.query);

	string username = formdata.get("username");
	string password = formdata.get("password");
	if (username == "yourid" && password == "secret")
	{
		if (!req.session)
			req.session = res.startSession;

		User user;
		user.loggedIn = true;
		user.name = username;
		req.session.set!User("user", user);
		res.redirect("/listnotes");
	}
	res.redirect("/");
}

void logout(HTTPServerRequest req, HTTPServerResponse res)
{
	req.session.set!User("user", User.init);
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

	res.redirect("/listnotes");
}

void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo info)
{
	render!("error.dt", req, info)(res);
}

struct Note
{
	string topic;
	string content;
}

struct User
{
	bool loggedIn;
	string name;
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

//use for basic authentication
bool checkPassword(string user, string password)
{
	return user == "yourid" && password == "secret";
}

// use for digest authentication
string digestPassword(string realm, string user)
{
	if (realm == "The Note app" && user == "yourid")
		return createDigestPassword(realm, user, "secret");
	return "";
}

// use for form authentication
void ensureAuth(HTTPServerRequest req, HTTPServerResponse res)
{
	if(req.session)
	{
		auto user = req.session.get!User("user");
		if (user.loggedIn)
			return;
	}
	res.redirect("/");
}

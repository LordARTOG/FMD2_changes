----------------------------------------------------------------------------------------------------
-- Module Initialization
----------------------------------------------------------------------------------------------------

function Init()
	local m = NewWebsiteModule()
	m.ID                       = '23eb3a472201427e8824ecdd5223bad7'
	m.Name                     = 'MangaFire'
	m.RootURL                  = 'https://mangafire.to'
	m.Category                 = 'English'
	m.OnGetDirectoryPageNumber = 'GetDirectoryPageNumber'
	m.OnGetNameAndLink         = 'GetNameAndLink'
	m.OnGetInfo                = 'GetInfo'
	m.OnGetPageNumber          = 'GetPageNumber'
	m.SortedList               = true

	local fmd = require 'fmd.env'
	local slang = fmd.SelectedLanguage
	local lang = {
		['en'] = {
			['lang'] = 'Language:',
			['chapterlist'] = 'Chapter list:',
			['type'] = 'Chapter\nVolume'
		},
		['id_ID'] = {
			['lang'] = 'Bahasa:',
			['chapterlist'] = 'Daftar bab:',
			['type'] = 'Bab\nJilid'
		},
		get =
			function(self, key)
				local sel = self[slang]
				if sel == nil then sel = self['en'] end
				return sel[key]
			end
	}

	local items = 'None'
	local t = GetLangList()
	for k, v in ipairs(t) do items = items .. '\r\n' .. v; end
	m.AddOptionComboBox('lang', lang:get('lang'), items, 1)
	m.AddOptionComboBox('chapterlist', lang:get('chapterlist'), lang:get('type'), 0)
end

----------------------------------------------------------------------------------------------------
-- Local Constants
----------------------------------------------------------------------------------------------------

DirectoryPagination = '/newest?page='

local function decode_unicode(str)
	return str:gsub("\\u(%x%x%x%x)", function(hex) return require("utf8").char(tonumber(hex, 16)) end)
end

----------------------------------------------------------------------------------------------------
-- Event Functions
----------------------------------------------------------------------------------------------------

-- Get the page count of the manga list of the current website.
function GetDirectoryPageNumber()
	local u = MODULE.RootURL .. DirectoryPagination .. 1

	if not HTTP.GET(u) then return net_problem end

	PAGENUMBER = tonumber(CreateTXQuery(HTTP.Document).XPathString('//ul[@class="pagination"]/li[last()]/a/@href/substring-after(., "=")')) or 1

	return no_error
end

-- Get links and names from the manga list of the current website.
function GetNameAndLink()
	local u = MODULE.RootURL .. DirectoryPagination .. (URL + 1)

	if not HTTP.GET(u) then return net_problem end

	CreateTXQuery(HTTP.Document).XPathHREFAll('//div[@class="info"]/a', LINKS, NAMES)

	return no_error
end

-- Get info and chapter list for the current manga.
function GetInfo()
	local langparam, optlang, optlangid, chapterlist, s, sel_chapterlist, v, x = nil
	local u = MaybeFillHost(MODULE.RootURL, URL)

	if not HTTP.GET(u) then return net_problem end

	x = CreateTXQuery(HTTP.Document)
	MANGAINFO.Title     = x.XPathString('//h1')
	MANGAINFO.CoverLink = x.XPathString('(//div[@class="poster"])[1]//img/@src')
	MANGAINFO.Authors   = x.XPathStringAll('//div[@class="meta"]/div[./span="Author:"]/span/a')
	MANGAINFO.Genres    = x.XPathStringAll('//div[@class="meta"]/div[./span="Genres:"]/span/a')
	MANGAINFO.Status    = MangaInfoStatusIfPos(x.XPathString('//div[@class="info"]/p'), 'Releasing|On_hiatus', 'Completed|Discontinued')
	MANGAINFO.Summary   = x.XPathString('string-join(//div[@class="modal-content p-4"]/text(), "\r\n")')

	chapterlist     = {'chapter', 'volume'}
	sel_chapterlist = (MODULE.GetOption('chapterlist') or 0) + 1
	optlang        = MODULE.GetOption('lang')
	optlangid      = FindLanguage(optlang)

	if optlangid == nil then langparam = '' else langparam = optlangid end

	if HTTP.GET(MODULE.RootURL .. '/ajax/read/' .. URL:match('%.(.-)$') .. '/' .. chapterlist[sel_chapterlist] .. '/' .. langparam) then
		s = decode_unicode(HTTP.Document.ToString():gsub('\\"', '"'))
		x = CreateTXQuery(s)
		x.ParseHTML(x.XPathString('json(*).result'))
		for v in x.XPath('//a').Get() do
			MANGAINFO.ChapterLinks.Add(v.GetAttribute('data-id'))
			MANGAINFO.ChapterNames.Add(x.XPathString('text()', v))
		end
	end
	MANGAINFO.ChapterLinks.Reverse(); MANGAINFO.ChapterNames.Reverse()

	return no_error
end

-- Get the page count for the current chapter.
function GetPageNumber()
	local chapterlist     = {'chapter', 'volume'}
	local sel_chapterlist = (MODULE.GetOption('chapterlist') or 0) + 1

	local u = MODULE.RootURL .. '/ajax/read/' .. chapterlist[sel_chapterlist] .. '/' .. URL:match('(%d+)')

	if not HTTP.GET(u) then return net_problem end

	CreateTXQuery(HTTP.Document).XPathStringAll('json(*).result.images()(1)', TASK.PageLinks)

	return no_error
end

local Langs = {
	["en"] = "English",
	["fr"] = "French",
	["ja"] = "Japanese",
	["pt-br"] = "Portuguese (Br)",
	["pt"] = "Portuguese (Pt)",
	["es-la"] = "Spanish (LATAM)",
	["es"] = "Spanish (Es)"
}

function GetLangList()
	local t = {}
	for k, v in pairs(Langs) do table.insert(t, v); end
	table.sort(t)
	return t
end

function FindLanguage(lang)
	local t = GetLangList()
	for i, v in ipairs(t) do
		if i == lang then
			lang = v
			break
		end
	end
	for k, v in pairs(Langs) do
		if v == lang then return k; end
	end
	return nil
end
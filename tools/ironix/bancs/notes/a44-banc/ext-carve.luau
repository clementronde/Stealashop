---------------------------------------------------------------- extensions a44 (L-081, vitre qui se creuse)
-- Ajouts au faux Roblox de la lignée a16 / a34 (variables locales PROPS, Methods, isA, newInstance,
-- games), collés juste après le stubs.luau du banc, dans le même fichier :
--   - propriété Reflectance des BasePart ;
--   - service GeometryService avec un faux FragmentAsync (voir GEOMETRY) ;
--   - service UserInputService (UIS_STUB : TouchEnabled, KeyboardEnabled) ;
--   - FIND_LOG : chaque nom cherché par FindFirstChild / WaitForChild (pour vérifier que plus rien ne
--     cherche WIN_Crack_*).
--
-- Faux FragmentAsync(part, sites, options) : attend GEOMETRY.Delay secondes de temps simulé (le vrai
-- est asynchrone), puis rend une liste { Instance, Index } : Index 1 = une copie de la pièce (le verre
-- qui reste) ; pour chaque autre site (un Vector3) dans la boîte de la pièce, un petit éclat (MeshPart
-- 0,3 × 0,3 × 0,15) posé au site. GEOMETRY.Island = true : rend aussi, dans le groupe 1, un petit
-- morceau loin du cadre (morceau détaché). GEOMETRY.Fail = true : lève une erreur après l'attente.
-- Journal : GEOMETRY.Calls (t, part, cf, size, sites, options, id, out) ; GEOMETRY.Active et
-- GEOMETRY.MaxActive = calculs en même temps, par vitre (Id lu dans le nom CarvedGlass_<Id>).
GEOMETRY = { Calls = {}, Delay = 0.03, Fail = false, Island = false, Active = {}, MaxActive = {} }
UIS_STUB = { TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true }
FIND_LOG = {}
do
	for _, class in { "Part", "MeshPart", "Terrain" } do
		local base = PROPS[class]
		PROPS[class] = function()
			local t = base()
			t.Reflectance = 0
			return t
		end
	end

	local find = Methods.FindFirstChild
	Methods.FindFirstChild = function(self, name, recursive)
		FIND_LOG[name] = (FIND_LOG[name] or 0) + 1
		return find(self, name, recursive)
	end
	local waitFor = Methods.WaitForChild
	Methods.WaitForChild = function(self, name, timeout)
		FIND_LOG[name] = (FIND_LOG[name] or 0) + 1
		return waitFor(self, name, timeout)
	end

	local function copyLook(to, from)
		for _, key in { "Material", "Color", "Transparency", "Reflectance", "Anchored", "CastShadow" } do
			rawget(to, "_props")[key] = rawget(from, "_props")[key]
		end
	end

	GeometryServiceStub = {
		FragmentAsync = function(_, part, sites, options)
			assert(getmetatable(part) == InstanceMT and isA(part, "BasePart"), "FragmentAsync : BasePart attendue")
			assert(type(sites) == "table" and #sites >= 2 and type(sites[1]) == "table", "FragmentAsync : groupe 1 (table) puis des sites")
			for i = 2, #sites do
				assert(getmetatable(sites[i]) == V3MT, "FragmentAsync : site " .. i .. " n'est pas un Vector3")
			end
			for _, s in sites[1] do
				assert(getmetatable(s) == V3MT, "FragmentAsync : site du groupe 1 qui n'est pas un Vector3")
			end
			local id = string.match(part.Name, "^CarvedGlass_(.+)$") or part.Name
			GEOMETRY.Active[id] = (GEOMETRY.Active[id] or 0) + 1
			GEOMETRY.MaxActive[id] = math.max(GEOMETRY.MaxActive[id] or 0, GEOMETRY.Active[id])
			local call = { t = now(), part = part, cf = part.CFrame, size = part.Size, sites = sites, options = options, id = id }
			table.insert(GEOMETRY.Calls, call)
			taskLib.wait(GEOMETRY.Delay)
			GEOMETRY.Active[id] -= 1
			call.done = now()
			if GEOMETRY.Fail then
				error("FragmentAsync en panne (banc)")
			end
			local out = {}
			local keep = newInstance(rawget(part, "_class"))
			keep.Name = part.Name
			copyLook(keep, part)
			keep.Size = call.size
			keep.CFrame = call.cf
			table.insert(out, { Instance = keep, Index = 1 })
			if GEOMETRY.Island then
				local island = newInstance("MeshPart")
				island.Name = part.Name
				copyLook(island, part)
				island.Size = Vector3.new(0.4, 0.4, 0.1)
				island.CFrame = call.cf * CFrame.new(0, 0, 0)
				table.insert(out, { Instance = island, Index = 1 })
			end
			local half = call.size / 2
			for i = 2, #sites do
				local p = call.cf:PointToObjectSpace(sites[i])
				if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
					local chip = newInstance("MeshPart")
					chip.Name = part.Name
					copyLook(chip, part)
					chip.Size = Vector3.new(0.3, 0.3, 0.15)
					chip.CFrame = CFrame.new(sites[i]) * call.cf.Rotation
					table.insert(out, { Instance = chip, Index = i })
				end
			end
			call.out = out
			return out
		end,
	}

	for _, g in games do
		local base = g.GetService
		g.GetService = function(self, name)
			if name == "GeometryService" then
				return GeometryServiceStub
			elseif name == "UserInputService" then
				return UIS_STUB
			end
			return base(self, name)
		end
	end
end

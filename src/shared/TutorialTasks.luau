--!strict
-- Liste des tâches du tutoriel (vague 60, a197 ; Cantin : « je savais pas qu'est-ce qu'il fallait qu'on fasse, où on
-- en était et pourquoi on faisait ça »). ReplicatedStorage/Shared/TutorialTasks, sans état, lu par TutorialController
-- (et les bancs). Textes : Config/Tutorial.Tasks (but, raison) et Config/Tutorial.Todos (ce qu'il faut faire,
-- progression) ; progression : have et need envoyés par le serveur avec l'étape (remote TutorialStep).
--
--   TutorialTasks.TaskIndex(step) -> number?      tâche de cette étape (nil : étape 0 ou inconnue)
--   TutorialTasks.Line(step, have?, need?) -> string?
--       ce qu'il faut faire : le texte Need rempli (« Earn cash: $100 / $300 to buy the Wrench ») tant que
--       have < need, sinon le texte Do (« Go to the Weapon Shop and buy it »)
--   TutorialTasks.Rows(step, have?, need?) -> { Row }
--       lignes à montrer : les tâches faites (cochées), la tâche en cours (Line, Why), puis TasksAhead tâches à
--       venir ; TasksMax lignes au plus (les tâches faites les plus anciennes partent d'abord)
--   TutorialTasks.Compact(step, have?, need?) -> string?
--       une ligne pour l'élément de texte de la bulle, tant que Clément n'a pas de panneau Tasks :
--       « Buy the Wrench (5/10): Earn cash: $100 / $300 to buy the Wrench »

local Tutorial = require(script.Parent.Config.Tutorial)
local Format = require(script.Parent.Format)

export type Row = {
	Index: number, -- numéro de la tâche (1 à #Tasks)
	Id: string,
	Goal: string,
	Why: string,
	Done: boolean,
	Current: boolean,
	Line: string?, -- tâche en cours seulement
}

local TutorialTasks = {}

-- Étape → numéro de sa tâche.
local byStep: { [number]: number } = {}
for index, task in Tutorial.Tasks do
	for _, step in task.Steps do
		byStep[step] = index
	end
end

function TutorialTasks.TaskIndex(step: number): number?
	return byStep[step]
end

local function finite(value: any): number?
	if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
		return value
	end
	return nil
end

local function formatValue(value: number, kind: string?): string
	value = math.max(0, value)
	if kind == "Money" then
		return Format.money(math.floor(value))
	elseif kind == "Seconds" then
		return `{math.floor(value)}s`
	elseif kind == "Time" then
		local seconds = math.ceil(value)
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return Format.short(math.floor(value))
end

function TutorialTasks.Line(step: number, have: number?, need: number?): string?
	local todo = Tutorial.Todos[step]
	if todo == nil then
		return nil
	end
	local h, n = finite(have), finite(need)
	local template = todo.Need
	if template and h and n and n > 0 and h < n then
		local kind = todo.NeedFormat
		local values: { [string]: string } = {
			["{have}"] = formatValue(h, kind),
			["{need}"] = formatValue(n, kind),
			["{left}"] = formatValue(n - h, kind),
		}
		return (string.gsub(template, "{%a+}", values))
	end
	return todo.Do
end

function TutorialTasks.Rows(step: number, have: number?, need: number?): { Row }
	local current = byStep[step]
	local rows: { Row } = {}
	if current == nil then
		return rows
	end
	local last = math.min(#Tutorial.Tasks, current + Tutorial.TasksAhead)
	local first = math.max(1, last - Tutorial.TasksMax + 1)
	first = math.min(first, current) -- la tâche en cours est toujours montrée
	for index = first, last do
		local task = Tutorial.Tasks[index]
		table.insert(rows, {
			Index = index,
			Id = task.Id,
			Goal = task.Goal,
			Why = task.Why,
			Done = index < current,
			Current = index == current,
			Line = if index == current then TutorialTasks.Line(step, have, need) else nil,
		})
	end
	return rows
end

function TutorialTasks.Compact(step: number, have: number?, need: number?): string?
	local current = byStep[step]
	if current == nil then
		return nil
	end
	local task = Tutorial.Tasks[current]
	local line = TutorialTasks.Line(step, have, need)
	local head = `{task.Goal} ({current}/{#Tutorial.Tasks})`
	return if line then `{head}: {line}` else head
end

return TutorialTasks

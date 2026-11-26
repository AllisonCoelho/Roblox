-- Toca a música ambiente procedural (regras em Shared/Dados/Musica). As notas usam só os sons
-- que já vêm com o Roblox (rbxasset), tocados em 2D (no SoundService) com o tom ajustado.
-- Muda de clima sozinha com o evento Despertar do Sol (atributo EventoFase do Workspace) e
-- respeita a opção "Música" dos Ajustes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Regras =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("Musica"))

local Musica = {}

local IDS = {
	ping = "rbxasset://sounds/electronicpingshort.wav",
	baixo = "rbxasset://sounds/bass.wav",
	batida = "rbxasset://sounds/clickfast.wav",
}
local VOZES = 6 -- sons por instrumento (tocam em rodízio)
local VOLUME_GERAL = 1

local ligada = true
local iniciada = false
local vozes: { [string]: { Sound } } = {}
local proxima: { [string]: number } = {}

local function criarVozes()
	local grupo = Instance.new("SoundGroup")
	grupo.Name = "MusicaAmbiente"
	grupo.Volume = VOLUME_GERAL
	grupo.Parent = SoundService
	for nome, id in IDS do
		vozes[nome] = {}
		proxima[nome] = 1
		for i = 1, VOZES do
			local s = Instance.new("Sound")
			s.Name = nome .. i
			s.SoundId = id
			s.SoundGroup = grupo
			s.Volume = 0
			s.Parent = grupo
			table.insert(vozes[nome], s)
		end
	end
end

local function tocar(n: Regras.Nota)
	local lista = vozes[n.som]
	if not lista then
		return
	end
	local i = proxima[n.som]
	proxima[n.som] = i % #lista + 1
	local s = lista[i]
	s.PlaybackSpeed = Regras.tom(n.semitons)
	s.Volume = n.volume
	s.TimePosition = 0
	s:Play()
end

function Musica.definir(ligar: boolean)
	ligada = ligar
	if not ligar then
		for _, lista in vozes do
			for _, s in lista do
				s:Stop()
			end
		end
	end
end

function Musica.iniciar()
	if iniciada then
		return
	end
	iniciada = true
	criarVozes()
	local aleatorio = Random.new()
	local function sorteio(): number
		return aleatorio:NextNumber()
	end
	task.spawn(function()
		local passo = 0
		local modoAnterior = ""
		local alvo = os.clock()
		while true do
			local modo = Regras.modo(Workspace:GetAttribute("EventoFase"))
			if modo ~= modoAnterior then
				-- troca de clima sempre no começo de um compasso
				modoAnterior = modo
				passo = 0
			end
			if ligada then
				for _, n in Regras.notas(modo, passo, sorteio) do
					tocar(n)
				end
			end
			passo += 1
			alvo += Regras.duracaoPasso(modo)
			local espera = alvo - os.clock()
			if espera < -0.5 then
				alvo = os.clock() -- ficou para trás (janela minimizada): não tenta recuperar
				espera = 0
			end
			task.wait(math.max(espera, 0))
		end
	end)
end

return Musica

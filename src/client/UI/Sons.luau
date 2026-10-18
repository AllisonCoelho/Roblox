-- Toca os sons da interface (lista em Shared/Dados/Sons.luau).
-- Efeitos e música podem ser desligados em Ajustes (fica salvo nos dados do jogador).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SonsDados = require(ReplicatedStorage.Shared.Dados.Sons)

local Sons = {}

local efeitosLigados = true
local cache: { [string]: Sound } = {}
local musica: Sound? = nil

local function criar(nome: string, def: SonsDados.Som): Sound
	local s = Instance.new("Sound")
	s.Name = "Som_" .. nome
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = def.velocidade
	s.Parent = SoundService
	return s
end

function Sons.tocar(nome: string)
	if not efeitosLigados then
		return
	end
	local def = SonsDados.Lista[nome]
	if not def or def.id == "" then
		return
	end
	local s = cache[nome]
	if not s then
		s = criar(nome, def)
		cache[nome] = s
	end
	s:Play()
end

-- Chamado quando chegam as preferências salvas (estado.config)
function Sons.aplicar(efeitos: boolean, comMusica: boolean)
	efeitosLigados = efeitos
	if SonsDados.Musica.id == "" then
		return
	end
	if not musica then
		local m = criar("Musica", SonsDados.Musica)
		m.Looped = true
		musica = m
	end
	local m = musica :: Sound
	if comMusica and not m.IsPlaying then
		m:Play()
	elseif not comMusica and m.IsPlaying then
		m:Stop()
	end
end

return Sons

## A hora do jogo. Funcao pura de um acumulador, sem Node e sem cena.
##
## Por que existe
## --------------
## Porque "22:43" estava escrito a mao em `abertura_estrada.gd` e em
## `hud_estrada.gd`, e o jogo nao tinha hora nenhuma: o relogio da Estrada Velha
## marcava 22:43 no primeiro minuto e 22:43 duas horas depois. Num jogo de
## horror onde o objetivo e chegar em algum lugar antes de amanhecer, um relogio
## parado nao e detalhe de interface — e a ausencia de uma pressao que o resto do
## desenho ja supoe que existe.
##
## Por que nao e autoload
## ----------------------
## Porque um autoload a mais e um arquivo a mais em `project.godot`, que e o
## arquivo que mais sofre com sessoes paralelas. `WorldState` ja e autoload, ja
## salva e ja carrega; o relogio mora dentro dele como um campo. Aqui fica so a
## conta, que e o que da para medir sem abrir janela.
class_name Relogio
extends RefCounted

const DIA := 24 * 60 * 60

## Quantas vezes o relogio do jogo corre mais rapido que o real.
##
## Por que 2,0 e nao 12,0 nem 1,0
## ------------------------------
## O jogo comeca 22:43 e a noite acaba as 05:00 — 377 minutos de jogo. A 2,0
## isso da 188 minutos reais, pouco mais de tres horas de partida ate clarear:
## tempo de sobra para a campanha inteira, sem que a noite seja eterna.
##
## A 12,0 (que e o ritmo comum de mundo aberto) o sol nasceria em 31 minutos de
## partida, e o jogo de terror noturno viraria jogo de manha no meio da segunda
## missao. A 1,0 o ponteiro se move tao devagar que o jogador nunca ve mudar, e
## um relogio que nunca muda e igual ao que nao existe.
##
## A 2,0 o minuto do mostrador vira a cada 30 s reais: rapido o bastante para o
## jogador perceber que o tempo anda, devagar o bastante para nao correr.
const RITMO := 2.0

## 22:43. O mesmo horario que a abertura sempre mostrou, agora num lugar so.
const INICIO := (22 * 60 + 43) * 60

## Amanhecer. Nao muda luz nenhuma ainda; existe para quem for perguntar.
const AURORA := 5 * 60 * 60

var segundos: float = float(INICIO)


func avancar(delta: float) -> void:
	segundos = fposmod(segundos + delta * RITMO, float(DIA))


## Minutos desde a meia-noite, 0..1439.
func minutos() -> int:
	return int(segundos / 60.0) % (24 * 60)


func texto() -> String:
	var m := minutos()
	return "%02d:%02d" % [m / 60, m % 60]


## Entre o por do sol e a aurora. O jogo inteiro acontece aqui hoje, mas quem
## acender poste ou espantar vaga-lume vai querer perguntar em vez de supor.
func e_noite() -> bool:
	var s := segundos
	return s >= float(18 * 60 * 60) or s < float(AURORA)


## Quanto falta para clarear, em minutos de jogo. Negativo nunca: depois da
## aurora devolve o dia inteiro.
func ate_a_aurora() -> int:
	var falta := float(AURORA) - segundos
	if falta < 0.0:
		falta += float(DIA)
	return int(falta / 60.0)


func definir_minutos(m: int) -> void:
	segundos = float(posmod(m, 24 * 60) * 60)


## Aceita "HH:MM". Devolve false e nao mexe no relogio se nao entender — quem
## chama e flag de captura, e flag errada nao pode parar o jogo.
func definir_texto(hhmm: String) -> bool:
	var partes := hhmm.split(":")
	if partes.size() != 2 or not partes[0].is_valid_int() or not partes[1].is_valid_int():
		return false
	definir_minutos(int(partes[0]) * 60 + int(partes[1]))
	return true

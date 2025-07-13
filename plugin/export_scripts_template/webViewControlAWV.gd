# WebViewControl.gd
# Versão unificada que usa godot-wry no Desktop e godot_awv no Android.
@icon("res://addons/godot_awv/icone.png") # Use o ícone que criamos
class_name WebViewControlAWV
extends Control

## SINAIS (Comuns aos dois plugins)
signal page_loaded(url: String)
signal ipc_message(message: String)
signal eval_result(result: String)

## PROPRIEDADES
@export_group("Configuração Inicial")
@export_multiline var html: String
@export var url: String
@export var transparent: bool = false
@export var autoplay: bool = true

@export_group("Desktop (godot-wry)")
# No editor, arraste o nó WebView do WRY para este campo.
@export var wry_node_path: NodePath

@export_group("Android (godot_awv)")
@export var full_window_size: bool = false:
	set(value):
		full_window_size = value
		if is_inside_tree() and _is_android: resize()
@export var background_color: Color = Color.TRANSPARENT
@export var devtools: bool = false
@export var user_agent: String = ""
@export var incognito: bool = false
@export var focused_when_created: bool = true
@export var forward_input_events: bool = false:
	set(value):
		forward_input_events = value
		mouse_filter = MOUSE_FILTER_PASS if value else MOUSE_FILTER_STOP

# Variáveis internas para guardar a referência ao plugin/nó correto
var _is_android: bool = false
var _android_plugin # Para o plugin Android
var _wry_node: Node # Para o nó do godot-wry

func _enter_tree() -> void:
	_is_android = (OS.get_name() == "Android")
	
	if _is_android:
		# LÓGICA PARA ANDROID
		if Engine.has_singleton("godot_awv"):
			_android_plugin = Engine.get_singleton("godot_awv")
		else:
			printerr("Plugin 'godot_awv' não encontrado no Android.")
			return
		
		var initial_settings = { "transparent": transparent, "autoplay": autoplay, "background_color": "#" + background_color.to_html(true), "devtools": devtools, "user_agent": user_agent, "incognito": incognito }
		_android_plugin.initialize(initial_settings)
		
		_android_plugin.page_loaded.connect(_on_page_loaded)
		_android_plugin.ipc_message.connect(_on_ipc_message)
		_android_plugin.eval_result.connect(_on_eval_result)
		
		resized.connect(resize)
		visibility_changed.connect(update_visibility)
		update_visibility()
		resize()
	else:
		# LÓGICA PARA DESKTOP (WRY)
		if not wry_node_path.is_empty():
			_wry_node = get_node_or_null(wry_node_path)
		
		if not _wry_node:
			printerr("Nó WebView do WRY não encontrado no caminho: ", wry_node_path)
			return

		# Conecta os sinais do WRY (os nomes podem ser um pouco diferentes)
		#_wry_node.page_loaded.connect(_on_page_loaded)
		_wry_node.ipc_message.connect(_on_ipc_message)
		# WRY pode não ter um sinal de eval_result, verifique a documentação dele.
		
		# WRY geralmente lida com o resize automaticamente, mas você pode adicionar lógica aqui se necessário.

	# Carregamento inicial
	if url:
		load_url(url)
	elif html:
		load_html(html)
	
	if focused_when_created:
		focus()


func _exit_tree() -> void:
	if _is_android and _android_plugin:
		_android_plugin.destroy()

# Funções "ponte" para os sinais
func _on_page_loaded(p_url: String):
	page_loaded.emit(p_url)

func _on_ipc_message(p_message: String):
	ipc_message.emit(p_message)

func _on_eval_result(p_result: String):
	eval_result.emit(p_result)

## MÉTODOS PÚBLICOS UNIFICADOS
func load_url(p_url: String):
	if _is_android and _android_plugin:
		_android_plugin.loadUrl(p_url)
	elif _wry_node:
		_wry_node.load_url(p_url)

func load_html(p_html: String):
	if _is_android and _android_plugin:
		_android_plugin.loadHtml(p_html)
	elif _wry_node:
		_wry_node.load_html(p_html)

func post_message(message: String):
	if _is_android and _android_plugin:
		_android_plugin.postMessage(message)
	elif _wry_node:
		_wry_node.post_message(message)

func eval(js: String):
	if _is_android and _android_plugin:
		_android_plugin.eval(js)
	elif _wry_node:
		_wry_node.eval(js)

func reload():
	if _is_android and _android_plugin:
		_android_plugin.reload()
	elif _wry_node:
		_wry_node.reload()

func focus():
	if _is_android and _android_plugin:
		_android_plugin.focus()
	elif _wry_node:
		_wry_node.focus()
		
# Métodos específicos do Android
func resize():
	if _is_android and _android_plugin:
		if full_window_size:
			var vp_size = get_viewport_rect().size
			_android_plugin.setPositionAndSize(0, 0, int(vp_size.x), int(vp_size.y))
		else:
			_android_plugin.setPositionAndSize(int(global_position.x), int(global_position.y), int(size.x), int(size.y))

func update_visibility():
	if _is_android and _android_plugin:
		_android_plugin.setVisible(is_visible_in_tree())

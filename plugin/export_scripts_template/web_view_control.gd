
@icon("./icon.png") # Coloque o ícone que criamos aqui!
class_name WebViewControl
extends Control

#region Sinais
signal page_loaded(url: String)
signal ipc_message(message: String)
signal eval_result(result: String)
#endregion

#region Propriedades (API do WRY)
@export var full_window_size: bool = false:
	set(value):
		full_window_size = value
		if is_inside_tree(): resize()

@export_multiline var html: String
@export var url: String = "https://github.com/pedrodenovo/Godot-AWV"

@export var transparent: bool = false
@export var autoplay: bool = true
@export var background_color: Color = Color.TRANSPARENT
@export var devtools: bool = false
@export var user_agent: String = ""
@export var incognito: bool = false
@export var focused_when_created: bool = true

@export var forward_input_events: bool = false:
	set(value):
		forward_input_events = value
		# Mapeia para a nossa implementação de mouse_filter
		mouse_filter = MOUSE_FILTER_PASS if value else MOUSE_FILTER_STOP
#endregion

var _plugin

func _enter_tree() -> void:
	if Engine.has_singleton("GodotAndroidWebView"):
		_plugin = Engine.get_singleton("GodotAndroidWebView")
	else:
		printerr("Plugin 'GodotAndroidWebView' não encontrado.")
		return

	# Empacota as configurações iniciais para enviar de uma vez
	var initial_settings = {
		"transparent": transparent,
		"autoplay": autoplay,
		"background_color": "#" + background_color.to_html(false),
		"devtools": devtools,
		"user_agent": user_agent,
		"incognito": incognito
	}
	_plugin.initialize(initial_settings)

	# ALTERADO: Conecta os sinais do plugin às novas funções "ponte".
	_plugin.page_loaded.connect(_on_plugin_page_loaded)
	_plugin.ipc_message.connect(_on_plugin_ipc_message)
	_plugin.eval_result.connect(_on_plugin_eval_result)

	# Sincronização automática
	resized.connect(resize)
	visibility_changed.connect(update_visibility)
	
	# Estado inicial
	update_visibility()
	resize()
	
	if url:
		load_url(url)
	elif html:
		load_html(html)
		
	if focused_when_created:
		focus()

func _exit_tree() -> void:
	if _plugin:
		_plugin.destroy()

func _set(property: StringName, value) -> bool:
	if property == &"mouse_filter":
		mouse_filter = value
		# Atualiza a propriedade 'forward_input_events' para consistência
		forward_input_events = (value == MOUSE_FILTER_PASS or value == MOUSE_FILTER_IGNORE)
		if _plugin:
			_plugin.setMouseFilterMode(value)
		return true
	return false

#region NOVO: Funções "ponte" para re-emitir os sinais
func _on_plugin_page_loaded(url: String) -> void:
	page_loaded.emit(url)

func _on_plugin_ipc_message(message: String) -> void:
	ipc_message.emit(message)
	
func _on_plugin_eval_result(result: String) -> void:
	eval_result.emit(result)
#endregion

#region Métodos Públicos (API do WRY)
func clear_all_Browse_data() -> void:
	if _plugin: _plugin.clearAllBrowseData()

func eval(js: String) -> void:
	if _plugin: _plugin.eval(js)

func focus() -> void:
	if _plugin: _plugin.focus()

func focus_parent() -> void:
	if _plugin: _plugin.focusParent()

func is_devtools_open() -> bool:
	return false # Não aplicável no Android

func load_html(p_html: String) -> void:
	if _plugin: _plugin.loadHtml(p_html)

func load_url(p_url: String) -> void:
	if _plugin: _plugin.loadUrl(p_url)

func open_devtools() -> void:
	print("open_devtools() não é suportado no Android.")

func close_devtools() -> void:
	print("close_devtools() não é suportado no Android.")

func post_message(message: String) -> void:
	if _plugin: _plugin.postMessage(message)

func print() -> void:
	if _plugin: _plugin.print()

func reload() -> void:
	if _plugin: _plugin.reload()

func resize() -> void:
	if not _plugin: return
	if full_window_size:
		var vp_size = get_viewport_rect().size
		_plugin.setPositionAndSize(0, 0, vp_size.x, vp_size.y)
	else:
		_plugin.setPositionAndSize(int(global_position.x), int(global_position.y), int(size.x), int(size.y))

func set_visible(p_visible: bool) -> void:
	visible = p_visible

func update_visibility() -> void:
	if _plugin: _plugin.setVisible(is_visible_in_tree())

func zoom(factor: float) -> void:
	if _plugin: _plugin.zoom(factor)
#endregion

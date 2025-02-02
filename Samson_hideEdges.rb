module HideEdgesInGroupsRecursive
  # 递归隐藏边线的函数
  def self.hide_edges_in_groups_recursive(entity)
    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      # 获取组或组件的定义
      definition = entity.definition
      definition.entities.each do |sub_entity|
        if sub_entity.is_a?(Sketchup::Edge)
          # 隐藏边线
          sub_entity.hidden = true
        elsif sub_entity.is_a?(Sketchup::Group) || sub_entity.is_a?(Sketchup::ComponentInstance)
          # 递归处理子组件
          hide_edges_in_groups_recursive(sub_entity)
        end
      end
    end
  end

  # 插件主功能
  def self.run_plugin
    model = Sketchup.active_model
    selection = model.selection

    # 开始操作
    model.start_operation('Hide Edges in Groups Recursive', true)

    selection.each do |entity|
      hide_edges_in_groups_recursive(entity)
    end

    # 结束操作
    model.commit_operation
  end

  # 添加上下文菜单项
  UI.add_context_menu_handler do |context_menu|
    # 检查是否有选中的组或组件
    selected_entities = Sketchup.active_model.selection
    has_groups_or_components = selected_entities.any? { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }

    if has_groups_or_components
      # 添加分隔线
      context_menu.add_separator
      # 添加菜单项
      context_menu.add_item("Hide Edges in Groups Recursive") {
        self.run_plugin
      }
    end
  end

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)
  end
end
# Samson_ScaleToHeight.rb
# SketchUp 2024 Plugin - 缩放物体到目标高度
#
# 功能说明：
#   1. 选中一个或多个组件/群组
#   2. 右键菜单选择"缩放物体"
#   3. 输入目标高度（单位跟随文件设置）
#   4. 以每个物体外轮廓底部中点为缩放中心进行整体等比缩放
#
# 使用方法：
#   将此文件放入 SketchUp Plugins 目录，重启 SketchUp 即可使用
#   选中组件/群组 → 右键 → "缩放物体" → 输入目标高度
#
# Author: Samson

require 'sketchup.rb'

module Samson
  module ScaleToHeight

    PLUGIN_NAME = "缩放物体".freeze

    #-------------------------------------------------------------------------
    # 检测选择集中是否包含至少一个组件或群组
    #-------------------------------------------------------------------------
    def self.has_valid_selection?
      model = Sketchup.active_model
      return false unless model
      sel = model.selection
      sel.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
    end

    #-------------------------------------------------------------------------
    # 从选择集中筛选出所有组件和群组（过滤掉边线、面等其他类型）
    #-------------------------------------------------------------------------
    def self.get_valid_entities
      model = Sketchup.active_model
      return [] unless model
      sel = model.selection
      sel.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
    end

    #-------------------------------------------------------------------------
    # 获取当前模型的长度单位显示文本
    #-------------------------------------------------------------------------
    def self.get_unit_string
      model = Sketchup.active_model
      return "" unless model
      unit_options = model.options["UnitsOptions"]
      length_unit = unit_options["LengthUnit"]
      case length_unit
      when 0 then "英寸(in)"
      when 1 then "英尺(ft)"
      when 2 then "毫米(mm)"
      when 3 then "厘米(cm)"
      when 4 then "米(m)"
      else ""
      end
    end

    #-------------------------------------------------------------------------
    # 对单个实体执行缩放
    # 以外轮廓底部中点为缩放中心，等比缩放到目标高度
    #
    # entity:        Sketchup::ComponentInstance 或 Sketchup::Group
    # target_height: 目标高度 (Length)
    #-------------------------------------------------------------------------
    def self.scale_entity(entity, target_height)
      bb = entity.bounds
      current_height = bb.max.z - bb.min.z

      # 高度为0的物体无法缩放
      return false if current_height <= 0

      # 计算缩放比例
      scale_factor = target_height.to_f / current_height.to_f

      # 计算底部中点（世界坐标）
      # 底部 = Z轴最小值所在面
      # 中点 = X、Y方向的中心
      center_x = (bb.min.x + bb.max.x) / 2.0
      center_y = (bb.min.y + bb.max.y) / 2.0
      center_z = bb.min.z

      # 构建以底部中点为中心的缩放变换
      # 变换顺序: 平移到原点 → 缩放 → 平移回原位
      # 数学等价: T(center) * S(scale) * T(-center)
      to_origin   = Geom::Transformation.translation([-center_x, -center_y, -center_z])
      scaling     = Geom::Transformation.scaling(scale_factor)
      from_origin = Geom::Transformation.translation([center_x, center_y, center_z])
      transform   = from_origin * scaling * to_origin

      entity.transform!(transform)
      return true
    end

    #-------------------------------------------------------------------------
    # 主执行入口
    #-------------------------------------------------------------------------
    def self.execute
      model = Sketchup.active_model
      return unless model

      # 1. 筛选有效实体（只保留组件和群组）
      entities = get_valid_entities
      if entities.empty?
        UI.messagebox("请先选择至少一个组件或群组。")
        return
      end

      # 2. 获取单位信息
      unit_str = get_unit_string

      # 3. 收集当前高度信息
      heights = entities.map do |e|
        bb = e.bounds
        bb.max.z - bb.min.z
      end
      min_h = heights.min
      max_h = heights.max

      height_info = if min_h == max_h
        "当前高度: #{min_h.to_l.to_s}"
      else
        "高度范围: #{min_h.to_l.to_s} ~ #{max_h.to_l.to_s}"
      end

      # 4. 弹出输入对话框（单位跟随文件设置）
      prompts  = ["目标高度 (单位:#{unit_str})"]
      defaults = [""]
      title    = "#{PLUGIN_NAME} - #{entities.length}个物体 | #{height_info}"

      result = UI.inputbox(prompts, defaults, title)
      return unless result  # 用户点击了取消

      input_str = result[0].to_s.strip
      if input_str.empty?
        UI.messagebox("未输入有效数据。")
        return
      end

      # 5. 解析输入
      # 支持纯数字（按文件单位解析）和带单位后缀（如 "1m", "100cm", "1000mm"）
      target_height = nil
      begin
        target_height = input_str.to_l
      rescue
        target_height = nil
      end

      if target_height.nil? || target_height <= 0
        UI.messagebox(
          "无法解析输入: \"#{input_str}\"\n" \
          "请输入有效的数值（如 1, 1.5, 1m, 100cm, 1000mm 等）。"
        )
        return
      end

      # 6. 执行缩放（包装为可撤销操作）
      model.start_operation(PLUGIN_NAME, true)

      success_count = 0
      skip_count = 0

      entities.each do |entity|
        begin
          if scale_entity(entity, target_height)
            success_count += 1
          else
            skip_count += 1
          end
        rescue
          skip_count += 1
        end
      end

      model.commit_operation

      # 7. 结果反馈
      msg = "缩放完成！成功 #{success_count} 个物体"
      msg += "，跳过 #{skip_count} 个（高度为0或出错）" if skip_count > 0
      msg += "。"
      UI.messagebox(msg)
    end

    #-------------------------------------------------------------------------
    # 注册右键上下文菜单
    # 仅当选中包含组件/群组时显示菜单项
    #-------------------------------------------------------------------------
    def self.register_context_menu
      UI.add_context_menu_handler do |context_menu|
        if has_valid_selection?
          context_menu.add_item(PLUGIN_NAME) do
            execute
          end
        end
      end
    end

  end # module ScaleToHeight
end # module Samson

#--------------------------------------------------------------------------
# 插件加载入口 - 确保只注册一次
#--------------------------------------------------------------------------
unless file_loaded?(__FILE__)
  Samson::ScaleToHeight.register_context_menu
  file_loaded(__FILE__)
end

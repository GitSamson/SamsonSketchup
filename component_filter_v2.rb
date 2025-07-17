# Enhanced Component Filter by Keywords Script for SketchUp
# Now works with components inside groups

module ComponentFilter
  # Add the command to the right-click context menu
  unless file_loaded?(__FILE__)
    UI.add_context_menu_handler do |context_menu|
      # Show menu when components or groups containing components are selected
      selection = Sketchup.active_model.selection
      if selection.grep(Sketchup::ComponentInstance).any? || 
         selection.grep(Sketchup::Group).any? { |g| contains_components?(g) }
        context_menu.add_separator
        context_menu.add_item("Filter Components by Keywords") { self.filter_components_by_keywords }
      end
    end
    file_loaded(__FILE__)
  end

  def self.contains_components?(entity)
    return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
    
    if entity.is_a?(Sketchup::ComponentInstance)
      true
    else
      entity.entities.any? do |e|
        e.is_a?(Sketchup::ComponentInstance) || 
        (e.is_a?(Sketchup::Group) && contains_components?(e))
      end
    end
  end

  def self.filter_components_by_keywords
    model = Sketchup.active_model
    selection = model.selection
    
    # Get keywords from user input
    prompts = ['Enter keywords to filter components (comma separated):']
    defaults = ['']
    title = 'Component Filter'
    input = UI.inputbox(prompts, defaults, title)
    
    return unless input # User cancelled
    
    keywords = input.first.to_s.downcase.split(',').map(&:strip)
    return if keywords.empty? # No keywords entered
    
    # Clear current selection
    selection.clear
    
    # Recursive function to find components in groups
    def self.find_components(entities, keywords, selection)
      entities.each do |entity|
        if entity.is_a?(Sketchup::ComponentInstance)
          definition = entity.definition
          definition_name = definition.name.downcase
          
          # Check if any keyword matches the component name
          if keywords.any? { |kw| definition_name.include?(kw) }
            selection.add(entity)
          end
        elsif entity.is_a?(Sketchup::Group)
          find_components(entity.entities, keywords, selection)
        end
      end
    end
    
    # Search through all entities in the model
    find_components(model.entities, keywords, selection)
    
    # Show result count
    UI.messagebox("Found #{selection.count} components matching your keywords.")
  end
end
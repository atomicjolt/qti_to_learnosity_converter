module CanvasQtiToLearnosityConverter
  module NewQuizzesSupport
    extend ActiveSupport::Concern

    # Canvas lets you create questions that are associated with a stimulus. Authoring
    # these in Learnosity is terrible if there are too many questions in the same item,
    # so we limit the number of questions per item to 30.
    MAX_QUESTIONS_PER_ITEM = 30

    def parent_stimulus_ident(item)
      if item.name == "bankentry_item" || item.name == "section"
        item.attribute("parent_stimulus_item_ident")&.value
      else
        item.css("itemmetadata > qtimetadata > qtimetadatafield > fieldlabel:contains('parent_stimulus_item_ident')").first&.next&.text
      end
    end

    def limit_child_questions(child_widgets, parent_ident)
      if child_widgets.count > MAX_QUESTIONS_PER_ITEM
        # We only want to include the first MAX_QUESTIONS_PER_ITEM questions
        child_widgets = child_widgets.first(MAX_QUESTIONS_PER_ITEM)
        @errors[parent_ident] ||= []
        @errors[parent_ident].push({
          error_type: "too_many_questions",
          message: "Too many questions for item, only the first #{MAX_QUESTIONS_PER_ITEM} will be included",
        })
      end

      child_widgets
    end

    def clone_bank_widget(parent_ident, child_item)
      # If the item is from a question bank we want to create a new copy of the widget
      # as Learnosity doesn't really share widgets between items
      child_item_ref = child_item.attribute("item_ref")&.value
      converted_widget = @widgets.find { |w| w[:metadata][:original_item_ref] == child_item_ref }

      if converted_widget.blank?
        raise "Could not find converted widget for item_ref #{child_item_ref}"
      end

      new_widget = converted_widget.deep_dup
      new_widget[:reference] = build_reference("#{parent_ident}_#{child_item_ref}")
      new_widget[:metadata][:original_item_ref] = "#{parent_ident}_#{child_item_ref}"
      new_widget
    end

    def convert_child_item(child_item:, path:, parent_ident:, new_references: false)
      if child_item.name == "section"
        item_refs = child_item.css("sourcebank_ref").map do |sourcebank_ref|
          @items.select do |i|
            (
              i.dig(:metadata, :original_item_bank_ref) == sourcebank_ref.text &&
              !(i.dig(:definition, :regions)&.any? { |r| r[:widgets].blank? }) # Exclude empty stimulus items
            )
          end.map { |i| i[:metadata][:original_item_ref] }
        end.flatten

        bank_widgets = item_refs.map { |ref| @widgets.find { |w| w[:metadata][:original_item_ref] == ref } }

        bank_widgets.map do |widget|
          new_widget = widget.deep_dup
          new_widget[:reference] = build_reference
          new_widget
        end
      elsif child_item.name == "bankentry_item"
        new_widget = clone_bank_widget(parent_ident, child_item)
        if new_references
          new_widget[:reference] = build_reference
        end
        new_widget
      else
        child_ident = child_item.attribute("ident")&.value
        child_learnosity_type, child_quiz_item = convert_item(qti_string: child_item.to_html)

        {
          type: child_learnosity_type,
          data: child_quiz_item.convert(@assets, path),
          reference: build_reference("#{parent_ident}_#{child_ident}"),
          metadata: { original_item_ref: child_ident },
        }
      end
    end

    # Canvas new quizzes can have a stimulus with associated questions. These have
    # a material orientation attribute that specifies the orientation of the stimulus.
    # We create a single Learnosity item with multiple widgets for these items.
    def build_item_definition(item, learnosity_type, quiz_item, path, child_items)
      ident = item.attribute("ident")&.value

      item_widgets = [{
        type: learnosity_type,
        data: quiz_item.convert(@assets, path),
        reference: build_reference("#{ident}_widget"),
        metadata: { original_item_ref: ident },
      }]

      definition = {}

      if item.css("presentation > material[orientation]").present?
        child_widgets = child_items.map do |child_item|
          convert_child_item(child_item:, path:, parent_ident: ident)
        end.flatten

        child_widgets = limit_child_questions(child_widgets, ident)

        item_widgets += child_widgets
      end

      if item.css("presentation > material[orientation='left']").present?
        definition[:regions] = [
          {
            widgets: [{ reference: item_widgets.first[:reference] }],
            width: 50,
            type: "column"
          },
          {
            widgets: child_widgets.map{ |w| { reference: w[:reference] } },
            width: 50,
            type: "column"
          }
        ]
        definition[:scroll] = { enabled: false }
        definition[:type] = "root"
      else
        definition[:widgets] = item_widgets.map{ |w| { reference: w[:reference] } }
      end

      [item_widgets, definition]
    end

    # We need to create a new item for stimuluses that are from a question bank, as
    # the item in the assessment will need to have multiple widgets in it, and the item
    # from the bank only has the stimulus. We don't want to modify the original item in
    # the bank as it could be used in multiple assessments and it's convenient to have
    # the original to clone. We also create new widgets, so that the item can be modified
    # without affecting any other items that use the same widgets.
    def clone_bank_item(parent_item, child_items, path)
      item_ref = parent_item.attribute("item_ref").value
      bank_item = @items.find { |i| i[:metadata][:original_item_ref] == item_ref }
      new_item = bank_item.deep_dup

      if new_item[:definition][:regions].blank?
        raise "Trying to add a child item to a stimulus from a question bank that wasn't converted with regions"
      end

      # We need new references throughout because we can't consistently generate
      # references when this stimulus/questions could be used in multiple assessments with
      # different questions for the same bank stimulus
      new_item[:reference] = build_reference

      # Use the bank item reference in the metadata so we don't accidentally
      # find this cloned one if the original is used elsewhere
      new_item[:metadata][:original_item_ref] = bank_item[:reference]

      cloned_stimulus = @widgets.find { |w| w[:metadata][:original_item_ref] == item_ref }.deep_dup
      cloned_stimulus[:reference] = build_reference
      @widgets.push(cloned_stimulus)

      stimulus_region = new_item[:definition][:regions].find { |r| r[:widgets].present? }
      stimulus_region[:widgets] = [{ reference: cloned_stimulus[:reference] }]

      empty_region = new_item[:definition][:regions].find { |r| r[:widgets].blank? }
      child_widgets = child_items.map do |child_item|
        convert_child_item(child_item:, path:, parent_ident: item_ref, new_references: true)
      end.flatten

      child_widgets = limit_child_questions(child_widgets, item_ref)

      empty_region[:widgets] = child_widgets.map{ |w| { reference: w[:reference] } }
      new_item[:questions] = child_widgets.select{ |w| w[:type] == "question" }.map{ |w| w[:reference] }
      new_item[:features] = [{ reference: cloned_stimulus[:reference] }]

      @widgets += child_widgets
      @items.push(new_item)
      new_item
    end
  end
end

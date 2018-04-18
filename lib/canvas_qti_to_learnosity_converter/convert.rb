require 'nokogiri'

module CanvasQtiToLearnosityConverter

#  export function convert(qti) {
#    const $ = cheerio.load(qti);
#    const items = [];
#    $('item').toArray().forEach((item) => {
#      const convertedItem = convertItem($, $(item));
#      if (!_.isNil(convertedItem)) { items.push(convertedItem); }
#    });
# 
#    const title = $('questestinterop > assessment').attr('title');
#    const ident = $('questestinterop > assessment').attr('ident');
#    return {
#      title,
#      ident,
#      items
#    };

  def self.convert_item(qti)
    nil
  end

  def self.convert(qti)
    nil
  end

end

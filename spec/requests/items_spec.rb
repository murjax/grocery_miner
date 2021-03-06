require 'rails_helper'

RSpec.describe 'Items', type: :request do
  let(:user) { create(:user) }

  before(:each) { sign_in user }

  describe 'GET index' do
    it 'returns user items' do
      item = create(:item, user: user)
      get items_path
      expect(json_response[:data].count).to eq(1)
      expect(json_response[:data].first['id']).to eq(item.id.to_s)
      expect(json_response[:data].first.dig(:attributes, :name)).to eq(item.name.to_s)
    end

    context 'sorting purchase frequency' do
      let(:item) { create(:item, user: user) }
      let(:other_item) { create(:item, user: user) }

      before do
        3.times do
          create(:purchase, user: user, item: item)
        end

        2.times do
          create(:purchase, user: user, item: other_item)
        end
      end

      it 'sorts by frequent purchase ascending' do
        get items_path, params: { sort: 'frequent_purchased' }
        expect(json_response_ids).to eq([other_item.id.to_s, item.id.to_s])
      end

      it 'sorts by frequent purchase descending' do
        get items_path, params: { sort: '-frequent_purchased' }
        expect(json_response_ids).to eq([item.id.to_s, other_item.id.to_s])
      end
    end

    context 'filter[purchased_in_month]' do
      let(:item) { create(:item, user: user) }
      let(:other_item) { create(:item, user: user) }
      let!(:this_month_purchase) { create(:purchase, item: item, purchase_date: Date.current, user: user) }
      let!(:last_month_purchase) { create(:purchase, item: other_item, purchase_date: Date.current - 40.days, user: user) }

      it 'filters items with purchases made in given month' do
        get items_path, params: { filter: { purchased_in_month: Date.current.strftime('%m/%d/%Y') } }
        expect(json_response_ids).to include(item.id.to_s)
        expect(json_response_ids).not_to include(other_item.id.to_s)
      end
    end
  end

  describe 'GET show' do
    context 'item belongs to user' do
      let!(:item) { create(:item, user: user) }
      it 'returns item' do
        get item_path(item)
        expect(json_response.dig(:data, :id)).to eq(item.id.to_s)
        expect(json_response.dig(:data, :attributes, :name)).to eq(item.name.to_s)
      end
    end

    context 'item does not belong to user' do
      let!(:item) { create(:item) }
      it 'is not found' do
        get item_path(item)
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'POST create' do
    it 'creates item and sets user to current user' do
      name = 'Apples'

      headers = { 'CONTENT_TYPE' => 'application/vnd.api+json' }
      post items_path, params: {
        data: {
          type: 'items',
          attributes: {
            name: name
          }
        }
      }.to_json, headers: headers

      item = Item.last

      expect(json_response.dig(:data, :id)).to eq(item.id.to_s)
      expect(json_response.dig(:data, :attributes, :name)).to eq(name)
      expect(item.user).to eq(user)
    end

    context 'invalid attributes' do
      it 'does not create item' do
        headers = { 'CONTENT_TYPE' => 'application/vnd.api+json' }
        post items_path, params: {
          data: {
            type: 'items',
            attributes: {
              name: nil
            },
            relationships: {
              user: {
                data: {
                  type: 'users',
                  id: user.id
                }
              }
            }
          }
        }.to_json, headers: headers
        expect(json_response[:errors].first[:title]).to eq("can't be blank")
        expect(response.status).to eq(422)
      end
    end
  end

  describe 'PUT update' do
    context 'item belongs to user' do
      let!(:item) { create(:item, user: user) }
      it 'updates item' do
        name = 'Apples'
        headers = { 'CONTENT_TYPE' => 'application/vnd.api+json' }

        put item_path(item), params: {
          data: {
            type: 'items',
            id: item.id,
            attributes: {
              name: name
            }
          }
        }.to_json, headers: headers

        expect(item.reload.name).to eq(name)
        expect(json_response.dig(:data, :attributes, :name)).to eq(name)
      end

      context 'invalid attributes' do
        it 'does not update item' do
          headers = { 'CONTENT_TYPE' => 'application/vnd.api+json' }

          put item_path(item), params: {
            data: {
              type: 'items',
              id: item.id,
              attributes: {
                name: nil
              }
            }
          }.to_json, headers: headers
          expect(item.reload.name).not_to be_nil

          expect(json_response[:errors].first[:title]).to eq("can't be blank")
          expect(response.status).to eq(422)
        end
      end
    end

    context 'item does not belong to user' do
      let!(:item) { create(:item) }
      it 'is not found' do
        name = 'Apples'
        headers = { 'CONTENT_TYPE' => 'application/vnd.api+json' }

        put item_path(item), params: {
          data: {
            type: 'items',
            id: item.id,
            attributes: {
              name: name
            }
          }
        }.to_json, headers: headers
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'DELETE destroy' do
    context 'item belongs to user' do
      it 'destroys item' do
        item = create(:item, user: user)
        delete item_path(item)
        expect { item.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(response.status).to eq(204)
      end
    end

    context 'item does not belong to user' do
      it 'does not destroy item' do
        item = create(:item)
        delete item_path(item)
        expect(response.status).to eq(404)
        expect(item.reload.destroyed?).to eq(false)
      end
    end

    context 'item is used by purchases' do
      it 'does not destroy item' do
        item = create(:item)
        create(:purchase, item: item)
        delete item_path(item)
        expect(response.status).to eq(404)
        expect(item.reload.destroyed?).to eq(false)
      end
    end
  end
end
